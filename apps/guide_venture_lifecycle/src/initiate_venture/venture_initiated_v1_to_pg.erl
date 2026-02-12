%%% @doc Emitter: venture_initiated_v1 -> pg (internal pub/sub)
%%% Publishes venture_initiated events to OTP process groups for
%%% internal integration (projections, process managers).
-module(venture_initiated_v1_to_pg).

-export([emit/1]).

-define(GROUP, venture_initiated_v1).
-define(SCOPE, pg).

%% @doc Emit venture_initiated_v1 event to pg group.
%% All processes joined to the group will receive {venture_initiated_v1, Event}.
-spec emit(map()) -> ok.
emit(Event) ->
    Message = {venture_initiated_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
