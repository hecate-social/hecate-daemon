%%% @doc Query facade for the LLM usage ETS read model.
%%%
%%% Each entry is keyed by call_id.
%%% @end
-module(project_llm_usage_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get_total_cost/0, get_cost_by_venture/1, get_cost_by_division/1,
         get_cost_by_agent/1, list_calls_by_venture/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, llm_calls).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Query API (reads directly from public ETS)
%%====================================================================

-spec get_total_cost() -> {ok, float()}.
get_total_cost() ->
    All = ets:tab2list(?TABLE),
    Total = lists:foldl(fun({_Key, #{cost_usd := C}}, Acc) when is_number(C) -> Acc + C;
                           (_, Acc) -> Acc
                        end, 0.0, All),
    {ok, Total}.

-spec get_cost_by_venture(binary()) -> {ok, float()}.
get_cost_by_venture(VentureId) ->
    {ok, sum_cost_by(venture_id, VentureId)}.

-spec get_cost_by_division(binary()) -> {ok, float()}.
get_cost_by_division(DivisionId) ->
    {ok, sum_cost_by(division_id, DivisionId)}.

-spec get_cost_by_agent(binary()) -> {ok, float()}.
get_cost_by_agent(AgentId) ->
    {ok, sum_cost_by(agent_id, AgentId)}.

-spec list_calls_by_venture(binary(), map()) -> {ok, [map()]}.
list_calls_by_venture(VentureId, Opts) ->
    Limit = maps:get(limit, Opts, 100),
    Offset = maps:get(offset, Opts, 0),
    All = ets:tab2list(?TABLE),
    Matched = [E || {_Key, #{venture_id := V} = E} <- All, V =:= VentureId],
    Sorted = lists:sort(fun(#{tracked_at := A}, #{tracked_at := B}) -> A >= B end, Matched),
    Page = lists:sublist(lists:nthtail(min(Offset, length(Sorted)), Sorted), Limit),
    {ok, Page}.

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

sum_cost_by(Field, Value) ->
    All = ets:tab2list(?TABLE),
    lists:foldl(fun({_Key, Entry}, Acc) ->
        case maps:get(Field, Entry, undefined) of
            Value2 when Value2 =:= Value ->
                case maps:get(cost_usd, Entry, 0.0) of
                    C when is_number(C) -> Acc + C;
                    _ -> Acc
                end;
            _ -> Acc
        end
    end, 0.0, All).
