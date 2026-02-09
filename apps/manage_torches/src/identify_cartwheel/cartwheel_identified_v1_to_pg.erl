%%% @doc Emitter: cartwheel_identified_v1 -> pg (internal pub/sub)
%%% Publishes cartwheel_identified events to OTP process groups for
%%% internal integration (process managers, same-daemon reactors).
%%%
%%% This complements cartwheel_identified_v1_to_mesh for external integration.
%%% Internal consumers (like manage_cartwheels) subscribe to pg for same-daemon
%%% events, and mesh for remote-daemon events.
-module(cartwheel_identified_v1_to_pg).

-export([emit/1]).

-define(GROUP, cartwheel_identified_v1).
-define(SCOPE, pg).

%% @doc Emit cartwheel_identified_v1 event to pg group.
%% All processes joined to the group will receive {cartwheel_identified_v1, Event}.
-spec emit(map()) -> ok.
emit(Event) ->
    Message = {cartwheel_identified_v1, Event},
    Members = pg:get_members(?SCOPE, ?GROUP),
    logger:debug("[cartwheel_identified_v1_to_pg] Emitting to ~p members", [length(Members)]),
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),
    ok.
