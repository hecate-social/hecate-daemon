%%% @doc Aggregate for LAN machines.
%%%
%%% Each machine gets its own stream keyed by MAC address.
%%% Stream: lanmachine-{mac} (e.g., lanmachine-aa:bb:cc:dd:ee:ff)
%%% Lives in site_store alongside the site aggregate.
-module(lan_machine_aggregate).
-behaviour(evoq_aggregate).

-include("lan_machine_state.hrl").
-include("lan_machine_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/1]).

-spec state_module() -> module().
state_module() -> lan_machine_state.

init(AggregateId) ->
    {ok, lan_machine_state:new(AggregateId)}.

-spec stream_id(binary()) -> binary().
stream_id(MAC) ->
    <<"lanmachine-", MAC/binary>>.

execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    lan_machine_state:apply_event(State, Event).

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(spot_lan_machine, State, Payload) ->
    %% Only produce event if this is first spot OR something changed
    case should_spot(State, Payload) of
        true -> maybe_spot_lan_machine:handle_from_map(Payload);
        false -> {error, no_change}  %% idempotent — no change
    end;

do_execute(dismiss_lan_machine, State, _Payload) ->
    case State#lan_machine_state.status band ?LAN_MACHINE_DISMISSED of
        0 -> maybe_dismiss_lan_machine:handle_from_map(#{});
        _ -> {error, already_dismissed}
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

%% ===================================================================
%% Change detection
%% ===================================================================

%% @private Decide if a spot event should be recorded.
%% First spot: always. After that: only if something meaningful changed.
should_spot(#lan_machine_state{status = 0}, _Payload) ->
    true;  %% never spotted before
should_spot(State, Payload) ->
    %% Check if IP, hostname, SSH, or hecate status changed
    OldIP = State#lan_machine_state.ip,
    OldHostname = State#lan_machine_state.hostname,
    OldSSH = State#lan_machine_state.ssh,
    OldHecateRunning = maps:get(running, State#lan_machine_state.hecate, false),
    NewIP = maps:get(ip, Payload, maps:get(<<"ip">>, Payload, OldIP)),
    NewHostname = maps:get(hostname, Payload, maps:get(<<"hostname">>, Payload, OldHostname)),
    NewSSH = maps:get(ssh, Payload, maps:get(<<"ssh">>, Payload, OldSSH)),
    NewHecate = maps:get(hecate, Payload, maps:get(<<"hecate">>, Payload, #{})),
    NewHecateRunning = maps:get(running, NewHecate, maps:get(<<"running">>, NewHecate, false)),
    (NewIP =/= OldIP) orelse
    (NewHostname =/= OldHostname) orelse
    (NewSSH =/= OldSSH) orelse
    (NewHecateRunning =/= OldHecateRunning).
