-module(incident_diagnosed_v1_to_pg).
-export([emit/1]).

-define(GROUP, incident_diagnosed_v1).
-define(SCOPE, pg).

emit(Event) ->
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) ->
        Pid ! {incident_diagnosed_v1, Event}
    end, Members).
