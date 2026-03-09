%%% @doc ETS-backed read model facade for the license offerings domain.
%%%
%%% Named ETS table:
%%%   - offerings (keyed by plugin_id)
%%%
%%% Creates the table on start_link, then the merged projection joins it
%%% via evoq_read_model_ets shared named table support.
%%% @end
-module(project_license_offerings_store).
-behaviour(gen_server).

-include_lib("guide_license_offering_lifecycle/include/offering_status.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2]).
-export([browse_offerings/0, get_offering/1, get_offering_by_plugin_id/1, get_author_listings/1]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(offerings, [public, named_table, set, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

%% -- Queries --

browse_offerings() ->
    All = ets:tab2list(offerings),
    Published = [E || {_K, #{status := S} = E} <- All, evoq_bit_flags:has(S, ?OFF_PUBLISHED)],
    Sorted = lists:sort(fun(#{name := A}, #{name := B}) -> A =< B end, Published),
    {ok, Sorted}.

get_offering(OfferingId) ->
    case ets:lookup(offerings, OfferingId) of
        [{_, Entry}] -> {ok, Entry};
        [] -> {error, not_found}
    end.

get_offering_by_plugin_id(PluginId) ->
    case ets:match_object(offerings, {'_', #{plugin_id => PluginId}}) of
        [{_, Entry} | _] -> {ok, Entry};
        [] -> {error, not_found}
    end.

get_author_listings(AuthorId) ->
    All = ets:tab2list(offerings),
    Matched = [E || {_K, #{author_id := Aid} = E} <- All, Aid =:= AuthorId],
    Sorted = lists:sort(fun(#{cataloged_at := A}, #{cataloged_at := B}) ->
        compare_desc(A, B)
    end, Matched),
    {ok, Sorted}.

%% -- Internal --

compare_desc(undefined, _) -> false;
compare_desc(_, undefined) -> true;
compare_desc(A, B) -> A >= B.
