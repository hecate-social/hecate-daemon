%%% @doc Emitter: test_generated_v1 -> pg
-module(test_generated_v1_to_pg).
-export([emit/1]).
-define(GROUP, test_generated_v1).
-define(SCOPE, pg).
-spec emit(map()) -> ok.
emit(Event) -> Message = {test_generated_v1, Event}, Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members), ok.
