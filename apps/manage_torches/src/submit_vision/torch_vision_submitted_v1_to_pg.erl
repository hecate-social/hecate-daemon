%%% @doc Emitter: torch_vision_submitted_v1 -> pg (internal pub/sub)
%%% Publishes torch_vision_submitted events to OTP process groups for
%%% internal integration (projections, process managers).
-module(torch_vision_submitted_v1_to_pg).

-export([emit/1]).

-define(GROUP, torch_vision_submitted_v1).
-define(SCOPE, pg).

%% @doc Emit torch_vision_submitted_v1 event to pg group.
%% All processes joined to the group will receive {torch_vision_submitted_v1, Event}.
-spec emit(map()) -> ok.
emit(Event) ->
    Message = {torch_vision_submitted_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
