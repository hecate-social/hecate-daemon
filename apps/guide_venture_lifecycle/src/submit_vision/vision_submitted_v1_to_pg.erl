%%% @doc Emitter: vision_submitted_v1 -> pg (internal pub/sub)
-module(vision_submitted_v1_to_pg).

-export([emit/1]).

-define(GROUP, vision_submitted_v1).
-define(SCOPE, pg).

-spec emit(map()) -> ok.
emit(Event) ->
    Message = {vision_submitted_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
