%%% @doc Aggregate for LAN machines.
%%%
%%% Each observer (BEAM node) owns its own observation of each MAC.
%%% Stream: lanmachine-{mac}-{observer_node} — keyed by (MAC, observer)
%%% so host00 and beam02 never contend on the same stream even when
%%% they spot the same machine.
%%%
%%% Lives in site_store alongside the site aggregate. site_store is
%%% clustered (Khepri/Ra); per-observer streams keep lan-observation
%%% writes conflict-free while the store still replicates all views
%%% cluster-wide (any node can query what any other node sees).
-module(lan_machine_aggregate).
-behaviour(evoq_aggregate).

-include("lan_machine_state.hrl").
-include("lan_machine_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/2]).

-spec state_module() -> module().
state_module() -> lan_machine_state.

init(AggregateId) ->
    {ok, lan_machine_state:new(AggregateId)}.

-spec stream_id(binary(), binary()) -> binary().
stream_id(MAC, Observer) ->
    <<"lanmachine-", MAC/binary, "-", Observer/binary>>.

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

do_execute(dismiss_lan_machine, State, Payload) ->
    case State#lan_machine_state.status band ?LAN_MACHINE_DISMISSED of
        0 -> maybe_dismiss_lan_machine:handle_from_map(Payload);
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
    %% Check if IP, hostname, SSH, or hecate-running status changed.
    %%
    %% NOTE: the stored state carries the `hecate' map with BINARY keys
    %% (it round-tripped through JSON in the event store), while a
    %% fresh scan payload uses ATOM keys. The old code did
    %% `maps:get(running, OldMap)' against the new value, so for any
    %% host actually running hecate the lookup missed the binary key,
    %% defaulted to `false', and reported a change on EVERY scan. That
    %% is what grew this per-machine stream into thousands of events
    %% and kept the optimistic-concurrency retry loop spinning. Extract
    %% `running' key-type-agnostically on both sides.
    OldIP = State#lan_machine_state.ip,
    OldHostname = State#lan_machine_state.hostname,
    OldSSH = State#lan_machine_state.ssh,
    OldHecateRunning = hecate_running(State#lan_machine_state.hecate),
    NewIP = maps:get(ip, Payload, maps:get(<<"ip">>, Payload, OldIP)),
    NewHostname = maps:get(hostname, Payload, maps:get(<<"hostname">>, Payload, OldHostname)),
    NewSSH = maps:get(ssh, Payload, maps:get(<<"ssh">>, Payload, OldSSH)),
    NewHecate = maps:get(hecate, Payload, maps:get(<<"hecate">>, Payload, #{})),
    NewHecateRunning = hecate_running(NewHecate),
    (NewIP =/= OldIP) orelse
    (NewHostname =/= OldHostname) orelse
    (NewSSH =/= OldSSH) orelse
    (NewHecateRunning =/= OldHecateRunning).

hecate_running(M) when is_map(M) ->
    maps:get(running, M, maps:get(<<"running">>, M, false));
hecate_running(_) ->
    false.
