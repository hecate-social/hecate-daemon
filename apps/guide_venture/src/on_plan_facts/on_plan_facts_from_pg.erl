-module(on_plan_facts_from_pg).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SCOPE, pg).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ok = ensure_pg_scope(),
    ok = pg:join(?SCOPE, plan_started_v1, self()),
    ok = pg:join(?SCOPE, plan_completed_v1, self()),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

handle_info({plan_started_v1, Event}, State) ->
    DivisionId = maps:get(division_id, Event, maps:get(<<"division_id">>, Event, undefined)),
    venture_state:record_process_started(DivisionId, plan),
    {noreply, State};

handle_info({plan_completed_v1, Event}, State) ->
    DivisionId = maps:get(division_id, Event, maps:get(<<"division_id">>, Event, undefined)),
    venture_state:record_process_completed(DivisionId, plan),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
