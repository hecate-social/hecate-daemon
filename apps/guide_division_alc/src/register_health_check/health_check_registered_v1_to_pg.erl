-module(health_check_registered_v1_to_pg).
-export([emit/1]).
-define(GROUP, health_check_registered_v1).
-define(SCOPE, pg).
-spec emit(map()) -> ok.
emit(Event) -> Message = {health_check_registered_v1, Event}, Members = pg:get_members(?SCOPE, ?GROUP), lists:foreach(fun(Pid) -> Pid ! Message end, Members), ok.
