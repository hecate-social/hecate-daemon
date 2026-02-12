-module(release_deployed_v1_to_pg).
-export([emit/1]).
-define(GROUP, release_deployed_v1).
-define(SCOPE, pg).
-spec emit(map()) -> ok.
emit(Event) -> Message = {release_deployed_v1, Event}, Members = pg:get_members(?SCOPE, ?GROUP), lists:foreach(fun(Pid) -> Pid ! Message end, Members), ok.
