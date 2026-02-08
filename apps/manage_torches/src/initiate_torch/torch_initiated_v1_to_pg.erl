%%% @doc Emitter: torch_initiated_v1 -> pg (internal pub/sub)
%%% Publishes torch_initiated events to OTP process groups for
%%% internal integration (projections, process managers).
-module(torch_initiated_v1_to_pg).

-export([emit/1]).

-define(GROUP, torch_initiated_v1).
-define(SCOPE, pg).

%% @doc Emit torch_initiated_v1 event to pg group.
%% All processes joined to the group will receive {torch_initiated_v1, Event}.
-spec emit(map()) -> ok.
emit(Event) ->
    Message = {torch_initiated_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
