%%% @doc Emitter: module_generated_v1 -> pg (internal pub/sub)
-module(module_generated_v1_to_pg).
-export([emit/1]).
-define(GROUP, module_generated_v1).
-define(SCOPE, pg).
-spec emit(map()) -> ok.
emit(Event) ->
    Message = {module_generated_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members), ok.
