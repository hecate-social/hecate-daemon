%%%-------------------------------------------------------------------
%%% @doc Bridge cache for edge relay escalation.
%%%
%%% Caches the result of WAN topic lookups so the edge relay doesn't
%%% repeatedly bridge the same topic to WAN. ETS-based with TTL expiry.
%%%
%%% Cache entries:
%%% - `{topic, has_wan_subscribers}` → true/false (TTL: 5 min)
%%% - Prevents repeated WAN subscription for topics that only exist locally
%%% - Invalidated when new WAN subscriptions are created
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_edge_relay_cache).

-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/0]).
-export([should_bridge/1, mark_bridged/1, invalidate/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, edge_relay_bridge_cache).
-define(TTL_MS, 300_000).        %% 5 minutes
-define(CLEANUP_MS, 60_000).     %% Clean expired entries every 60s

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Check if a topic has been bridged to WAN recently.
%% Returns `bridge` if not cached (should bridge), `skip` if already bridged.
-spec should_bridge(binary()) -> bridge | skip.
should_bridge(Topic) ->
    Now = erlang:monotonic_time(millisecond),
    case ets:lookup(?TABLE, Topic) of
        [{_, ExpiresAt}] when ExpiresAt > Now -> skip;
        _ -> bridge
    end.

%% @doc Mark a topic as bridged to WAN (cache for TTL).
-spec mark_bridged(binary()) -> ok.
mark_bridged(Topic) ->
    ExpiresAt = erlang:monotonic_time(millisecond) + ?TTL_MS,
    ets:insert(?TABLE, {Topic, ExpiresAt}),
    ok.

%% @doc Invalidate a topic's cache entry (e.g., on unsubscribe).
-spec invalidate(binary()) -> ok.
invalidate(Topic) ->
    ets:delete(?TABLE, Topic),
    ok.

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}]),
    erlang:send_after(?CLEANUP_MS, self(), cleanup),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(cleanup, State) ->
    Now = erlang:monotonic_time(millisecond),
    %% Delete expired entries
    ets:select_delete(?TABLE, [{{{'_', '$1'}}, [{'<', '$1', Now}], [true]}]),
    erlang:send_after(?CLEANUP_MS, self(), cleanup),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
