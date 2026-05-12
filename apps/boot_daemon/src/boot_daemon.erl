%%% @doc boot_daemon facade — public API for the tier-1 application.
%%%
%%% hecate_app (tier-1) wires its store catalog into boot_daemon via
%%% register_stores/1 once reckon_db + evoq are up. boot_daemon does
%%% not own the store catalog — that's domain knowledge belonging to
%%% the hecate root app. boot_daemon owns the mechanics of spawning,
%%% tracking, sequencing post-boot, and the site-relay pg seam.
%%%
%%% The facade exposes:
%%%   register_stores/1   — hand a store list to boot_tracker + spawner.
%%%   get_status/0        — current boot phase + store readiness map.
%%%   set_phase/1         — forwarded to boot_tracker.
%%%   broadcast_to_site/2 — publish a realm-membership event to the
%%%                         other daemons in this site (pg group).
%%%   site_daemons_group/0 — the pg group name every daemon's
%%%                         listen_for_inherited_realm_memberships joins.
%%% @end
-module(boot_daemon).

-export([
    register_stores/1,
    get_status/0,
    set_phase/1,
    set_running/0,
    broadcast_to_site/2,
    site_daemons_group/0
]).

%% pg group spanning the site (the co-located daemon cluster).
-define(SITE_DAEMONS_GROUP, {boot_daemon, site_realm_memberships}).

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

%% @doc Publish a realm-membership event to the other daemons in this
%% site (everyone in the pg group except self). The local
%% relay_realm_events_to_site PM calls this; each remote
%% listen_for_inherited_realm_memberships receives a
%% {site_realm_event, EventType, Payload, FromDaemon} message.
%%
%% EventType is the binary event_type (e.g. <<"realm_credentials_secured_v1">>).
-spec broadcast_to_site(binary(), map()) -> ok.
broadcast_to_site(EventType, Payload) ->
    Msg = {site_realm_event, EventType, Payload, node()},
    Members = try pg:get_members(?SITE_DAEMONS_GROUP) catch _:_ -> [] end,
    Others = [P || P <- Members, node(P) =/= node()],
    [P ! Msg || P <- Others],
    ok.

-spec site_daemons_group() -> term().
site_daemons_group() -> ?SITE_DAEMONS_GROUP.
