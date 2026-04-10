%%%-------------------------------------------------------------------
%%% @doc Central topic builder for hecate-daemon.
%%%
%%% All mesh topics in the daemon MUST be built through this module.
%%% Topics follow the macula_topic convention:
%%%
%%%   {realm}/{org}/{app}/{domain}/{name}_v{N}
%%%
%%% The daemon's app_id is "hecate-social/hecate".
%%% Realm comes from application env.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_topics).

-export([
    fact/3,
    hope/3,
    realm/0,
    app_id/0
]).

-define(APP_ID, <<"beam-campus/hecate">>).

%% @doc Build a fact topic (pub/sub — something that happened).
-spec fact(binary(), binary(), pos_integer()) -> binary().
fact(Domain, Name, Version) ->
    macula_topic:fact(realm(), ?APP_ID, Domain, Name, Version).

%% @doc Build a hope topic (RPC procedure — something we want to happen).
-spec hope(binary(), binary(), pos_integer()) -> binary().
hope(Domain, Name, Version) ->
    macula_topic:hope(realm(), ?APP_ID, Domain, Name, Version).

%% @doc Get the current realm from application env.
-spec realm() -> binary().
realm() ->
    application:get_env(hecate, realm, <<"io.macula">>).

%% @doc The daemon's app_id.
-spec app_id() -> binary().
app_id() ->
    ?APP_ID.
