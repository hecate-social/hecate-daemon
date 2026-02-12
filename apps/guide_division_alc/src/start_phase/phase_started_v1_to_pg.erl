%%% @doc Emitter: phase_started_v1 -> pg (internal pub/sub)
%%% Publishes phase_started events to OTP process groups for
%%% internal integration (projections, process managers).
-module(phase_started_v1_to_pg).

-export([emit/1]).

-define(GROUP, phase_started_v1).
-define(SCOPE, pg).

%% @doc Emit phase_started_v1 event to pg group.
-spec emit(map()) -> ok.
emit(Event) ->
    Message = {phase_started_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
