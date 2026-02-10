-module(discovery_resumed_v1_to_pg).
-export([emit/1]).

-define(GROUP, discovery_resumed_v1).
-define(SCOPE, pg).

emit(Event) ->
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! {discovery_resumed_v1, Event} end, Members).
