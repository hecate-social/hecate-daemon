%%% @doc Emitter: desk_planned_v1 -> pg (internal pub/sub)
-module(desk_planned_v1_to_pg).
-export([emit/1]).
-define(GROUP, desk_planned_v1).
-define(SCOPE, pg).

-spec emit(map()) -> ok.
emit(Event) ->
    Message = {desk_planned_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
