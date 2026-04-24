%%% @doc boot_daemon facade — public API for the tier-1 application.
%%%
%%% hecate_app (tier-1) wires its store catalog into boot_daemon via
%%% register_stores/1 once reckon_db + evoq are up. boot_daemon does
%%% not own the store catalog — that's domain knowledge belonging to
%%% the hecate root app. boot_daemon owns the mechanics of spawning,
%%% tracking, sequencing post-boot, and pg relay.
%%%
%%% The facade exposes:
%%%   register_stores/1 — hand a store list to boot_tracker + spawner.
%%%   get_status/0      — current boot phase + store readiness map.
%%%   set_phase/1       — hecate_boot_tracker used to own this; now
%%%                       forwarded to boot_tracker.
%%%   broadcast_inherited/2 — publish an inherited-event message to
%%%                       peers in the pg group.
%%% @end
-module(boot_daemon).

-export([
    register_stores/1,
    get_status/0,
    set_phase/1,
    set_running/0,
    broadcast_inherited/2,
    inherited_pg_group/0
]).

-define(INHERITED_PG_GROUP, {boot_daemon, inherited_realm_memberships}).

%% @doc Hand the full store catalog to boot_tracker so it can spawn
%% stores sequentially and track readiness. Called by hecate_app.
-spec register_stores([{atom(), string(), string()}]) -> ok.
register_stores(Stores) ->
    boot_tracker:register_stores(Stores).

-spec get_status() -> map().
get_status() ->
    boot_tracker:get_status().

-spec set_phase(atom()) -> ok.
set_phase(Phase) ->
    boot_tracker:set_phase(Phase).

-spec set_running() -> ok.
set_running() ->
    boot_tracker:set_running().

%% @doc Publish an inherited-realm-memberships message to every peer
%% subscribed to the pg group. The local relay PM calls this; the
%% remote listener (listen_for_inherited_realm_memberships) receives.
%%
%% EventType is the binary event_type (e.g. <<"realm_membership_confirmed_v1">>).
%% Payload is the event map — re-dispatched as a command on the receiver.
-spec broadcast_inherited(binary(), map()) -> ok.
broadcast_inherited(EventType, Payload) ->
    Msg = {inherited_realm_event, EventType, Payload, node()},
    Members = try pg:get_members(?INHERITED_PG_GROUP) catch _:_ -> [] end,
    Peers = [P || P <- Members, node(P) =/= node()],
    [P ! Msg || P <- Peers],
    ok.

-spec inherited_pg_group() -> term().
inherited_pg_group() -> ?INHERITED_PG_GROUP.
