%%% @doc Emitter: test_result_recorded_v1 -> pg
-module(test_result_recorded_v1_to_pg).
-export([emit/1]).
-define(GROUP, test_result_recorded_v1).
-define(SCOPE, pg).
-spec emit(map()) -> ok.
emit(Event) -> Message = {test_result_recorded_v1, Event}, Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members), ok.
