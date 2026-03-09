%%% @doc ETS-backed read model facade for the procurements domain.
%%%
%%% Named ETS table:
%%%   - procurements (keyed by procurement_id)
%%%
%%% Creates the table on start_link, then projections join it
%%% via evoq_read_model_ets shared named table support.
%%% @end
-module(project_procurements_store).
-behaviour(gen_server).

-include_lib("guide_procurement_lifecycle/include/procurement_status.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2]).

%% Procurement queries
-export([get_procurement/1, list_procurements/1]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(procurements, [public, named_table, set, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

%% -- Procurement queries --

-spec get_procurement(binary()) -> {ok, map()} | {error, not_found}.
get_procurement(ProcurementId) ->
    case ets:lookup(procurements, ProcurementId) of
        [{_, Entry}] -> {ok, Entry};
        [] -> {error, not_found}
    end.

-spec list_procurements(binary()) -> {ok, [map()]}.
list_procurements(ConsumerId) ->
    All = ets:tab2list(procurements),
    Matched = [E || {_K, #{consumer_id := Cid, status := S} = E} <- All,
               Cid =:= ConsumerId, evoq_bit_flags:has_not(S, ?PROC_ARCHIVED)],
    Sorted = lists:sort(fun(#{initiated_at := A}, #{initiated_at := B}) ->
        compare_desc(A, B)
    end, Matched),
    {ok, Sorted}.

%% -- Internal --

compare_desc(undefined, _) -> false;
compare_desc(_, undefined) -> true;
compare_desc(A, B) -> A >= B.
