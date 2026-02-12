%%% @doc Emitter: division_initiated_v1 -> pg (internal pub/sub)
%%% Publishes division_initiated events to OTP process groups for
%%% internal integration (projections, process managers).
-module(division_initiated_v1_to_pg).

-export([emit/1]).

-define(GROUP, division_initiated_v1).
-define(SCOPE, pg).

%% @doc Emit division_initiated_v1 event to pg group.
%% All processes joined to the group will receive {division_initiated_v1, Event}.
-spec emit(map()) -> ok.
emit(Event) ->
    Message = {division_initiated_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
