%%% @doc Query facade for the realm memberships ETS read model.
%%%
%%% Multiple rows keyed by membership_id.
%%% The table is created here and shared with the merged projection
%%% via evoq_read_model_ets named table support.
%%% @end
-module(project_realm_memberships_store).
-behaviour(gen_server).

-include_lib("guide_realm_memberships/include/membership_status.hrl").

-export([start_link/0]).
-export([get/1, list_confirmed/0, list_all/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, realm_memberships).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Query API (reads directly from public ETS)
%%====================================================================

-spec get(binary()) -> {ok, map()} | {error, not_found}.
get(MembershipId) ->
    case ets:lookup(?TABLE, MembershipId) of
        [{_, Entry}] -> {ok, Entry};
        [] -> {error, not_found}
    end.

-spec list_confirmed() -> {ok, [map()]}.
list_confirmed() ->
    All = ets:tab2list(?TABLE),
    Confirmed = [E || {_Key, #{status := S} = E} <- All,
                      is_integer(S), evoq_bit_flags:has(S, ?MEMBERSHIP_CONFIRMED)],
    Sorted = lists:sort(fun(#{confirmed_at := A}, #{confirmed_at := B}) ->
        compare_timestamps(A, B)
    end, Confirmed),
    {ok, Sorted}.

-spec list_all() -> {ok, [map()]}.
list_all() ->
    All = ets:tab2list(?TABLE),
    {ok, [E || {_Key, E} <- All]}.

%%====================================================================
%% gen_server (owns the ETS table)
%%====================================================================

init([]) ->
    ?TABLE = ets:new(?TABLE, [set, public, named_table, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal
%%====================================================================

compare_timestamps(undefined, _) -> true;
compare_timestamps(_, undefined) -> false;
compare_timestamps(A, B) -> A =< B.
