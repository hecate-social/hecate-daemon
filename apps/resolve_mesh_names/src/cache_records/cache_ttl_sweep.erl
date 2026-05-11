%%% @doc cache_ttl_sweep: periodic TTL fallback eviction
%%% (PLAN_RESOLVE_MESH_NAMES_PART1 §6.3).
%%%
%%% Push invalidation (the two PMs subscribed to mesh push events)
%%% is the primary mechanism for cache eviction. This sweep is the
%%% safety net for entries we missed a push notification for
%%% (network glitch, subscription lapse, the substrate being
%%% bounced, etc.).
%%%
%%% Sweep period: 30 s default, configurable via app env
%%% `cache_ttl_sweep_period_ms'. Each sweep walks all 5 layers in
%%% sequence; entries past `expires_at' are deleted. Uses
%%% `cache_records:all_keys/1' + `cache_records:get/2' (which
%%% lazily evicts stale entries via the cast-to-evict path) — so
%%% the sweep doesn't need to know each layer's value shape.
%%% @end
-module(cache_ttl_sweep).
-behaviour(gen_server).

-export([start_link/0, sweep_now/0, last_sweep_evicted/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(DEFAULT_PERIOD_MS, 30000).

%% @doc Trigger an immediate sweep (in addition to the periodic
%% timer). Used by tests + operator commands.
-spec sweep_now() -> {ok, non_neg_integer()}.
sweep_now() ->
    gen_server:call(?MODULE, sweep_now).

%% @doc How many entries the most recent sweep evicted. Diagnostic.
-spec last_sweep_evicted() -> non_neg_integer().
last_sweep_evicted() ->
    gen_server:call(?MODULE, last_sweep_evicted).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Period = application:get_env(resolve_mesh_names,
                                 cache_ttl_sweep_period_ms,
                                 ?DEFAULT_PERIOD_MS),
    {ok, _Tref} = timer:send_interval(Period, self(), sweep),
    {ok, #{period_ms => Period, last_evicted => 0}}.

handle_call(sweep_now, _From, State) ->
    Evicted = do_sweep(),
    {reply, {ok, Evicted}, State#{last_evicted := Evicted}};
handle_call(last_sweep_evicted, _From, #{last_evicted := N} = State) ->
    {reply, N, State};
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast(_Msg, S) -> {noreply, S}.

handle_info(sweep, State) ->
    Evicted = do_sweep(),
    {noreply, State#{last_evicted := Evicted}};
handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Sweep implementation
%%====================================================================

%% Walk every layer; for each key, call cache_records:get/2 which
%% lazily evicts stale entries as a side effect. Counts evictions
%% by comparing pre/post sizes.
do_sweep() ->
    lists:foldl(fun(Layer, Acc) ->
        Acc + sweep_layer(Layer)
    end, 0, [l1, l2, l3, l4, l5]).

sweep_layer(Layer) ->
    Before = cache_records:size(Layer),
    Keys = cache_records:all_keys(Layer),
    lists:foreach(fun(K) ->
        %% get/2's stale-detection path issues an evict_stale cast
        %% on miss. Synchronously force eviction by also calling
        %% delete on entries we know are stale.
        case cache_records:get(Layer, K) of
            {ok, _, _} -> ok;
            miss       -> cache_records:delete(Layer, K)
        end
    end, Keys),
    After = cache_records:size(Layer),
    Before - After.
