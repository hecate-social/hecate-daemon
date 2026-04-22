%%%-------------------------------------------------------------------
%%% @doc Central topic builder for hecate-daemon.
%%%
%%% All mesh topics in the daemon MUST be built through this module.
%%% Topics follow the macula_topic 5-segment convention:
%%%
%%%   {realm}/{publisher}/{publisher}/{domain}/{name}_v{N}
%%%
%%% Three ownership tiers — pick the right builder for the topic's
%%% authority (NOT for who happens to publish a given instance):
%%%
%%%   realm — realm authority owns the schema (membership, identity, ban)
%%%   org   — org-spanning concept across multiple of beam-campus' apps
%%%           (commercial licensing, billing)
%%%   app   — internal to hecate (game state, RPCs, app-specific events)
%%%
%%% This wrapper pre-fills realm() and the (org, app) constants so
%%% call-sites stay short. The realm constant comes from application
%%% env (`{hecate, realm, ...}`); the org and app are compile-time
%%% per the daemon's identity.
%%%
%%% Authoritative spec:
%%%   macula-io/macula/docs/guides/TOPIC_NAMING_GUIDE.md
%%%
%%% Hecate-flavored guide:
%%%   hecate-social/hecate-agents/skills/MESH_TOPIC_TIERING.md
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_topics).

-export([
    realm_fact/3, realm_hope/3,
    org_fact/3,   org_hope/3,
    app_fact/3,   app_hope/3,
    realm/0,
    org/0,
    app/0
]).

-define(ORG, <<"beam-campus">>).
-define(APP, <<"hecate">>).

%%====================================================================
%% Realm tier — for realm authority concepts (membership, identity)
%%====================================================================

-spec realm_fact(binary(), binary(), pos_integer()) -> binary().
realm_fact(Domain, Name, Version) ->
    macula_topic:realm_fact(realm(), Domain, Name, Version).

-spec realm_hope(binary(), binary(), pos_integer()) -> binary().
realm_hope(Domain, Name, Version) ->
    macula_topic:realm_hope(realm(), Domain, Name, Version).

%%====================================================================
%% Org tier — for beam-campus-spanning concepts (licensing, billing)
%%====================================================================

-spec org_fact(binary(), binary(), pos_integer()) -> binary().
org_fact(Domain, Name, Version) ->
    macula_topic:org_fact(realm(), ?ORG, Domain, Name, Version).

-spec org_hope(binary(), binary(), pos_integer()) -> binary().
org_hope(Domain, Name, Version) ->
    macula_topic:org_hope(realm(), ?ORG, Domain, Name, Version).

%%====================================================================
%% App tier — for hecate-internal concepts (mpong, llm, site)
%%====================================================================

-spec app_fact(binary(), binary(), pos_integer()) -> binary().
app_fact(Domain, Name, Version) ->
    macula_topic:app_fact(realm(), ?ORG, ?APP, Domain, Name, Version).

-spec app_hope(binary(), binary(), pos_integer()) -> binary().
app_hope(Domain, Name, Version) ->
    macula_topic:app_hope(realm(), ?ORG, ?APP, Domain, Name, Version).

%%====================================================================
%% Constants
%%====================================================================

-spec realm() -> binary().
realm() ->
    application:get_env(hecate, realm, <<"io.macula">>).

-spec org() -> binary().
org() -> ?ORG.

-spec app() -> binary().
app() -> ?APP.
