-module(health_status_recorded_v1_to_pg).
-export([emit/1]).

-define(GROUP, health_status_recorded_v1).
-define(SCOPE, pg).

emit(Event) ->
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) ->
        Pid ! {health_status_recorded_v1, Event}
    end, Members).
