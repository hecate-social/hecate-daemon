%%% @doc CT suite for the two cache-invalidation PMs.
%%% PLAN_RESOLVE_MESH_NAMES_PART1 §6.2.
%%%
%%% Covers on_record_observed_invalidate_cache +
%%% on_realm_directory_changed_warm_cache. The macula
%%% subscribe_records layer is NOT exercised here (it's a thin
%%% wrapper); tests drive the PMs via their `on_record/2' entry
%%% point, which is exactly what the subscribe callback forwards.
%%%
%%% Coverage:
%%%   - realm_directory tombstone → precise by-realm invalidation
%%%     (reverse-looked-up via L1)
%%%   - realm_directory tombstone for an UNCACHED realm → no-op
%%%   - RME tombstone (hashed key) → coarse: nuke L5
%%%   - leaf tombstone → coarse: nuke L5
%%%   - RME version-bump observed → by-realm invalidation
%%%   - realm_directory version-bump observed (warm-cache PM) →
%%%     by-realm invalidation
%%%   - FRTL version-bump observed (warm-cache PM) → invalidates
%%%     every realm anchored to that foundation
%%%   - both PMs leave OTHER realms alone
%%% @end
-module(push_invalidation_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    dir_tombstone_invalidates_realm_subtree/1,
    dir_tombstone_for_uncached_realm_is_noop/1,
    rme_tombstone_nukes_l5/1,
    leaf_tombstone_nukes_l5/1,
    rme_version_bump_invalidates_realm/1,
    dir_version_bump_invalidates_realm/1,
    frtl_version_bump_invalidates_anchored_realms/1,
    invalidation_leaves_other_realms_alone/1
]).

-define(TYPE_REALM_DIRECTORY,              16#03).
-define(TYPE_REALM_MEMBER_ENDORSEMENT,     16#05).
-define(TYPE_TOMBSTONE,                    16#0C).
-define(TYPE_FOUNDATION_REALM_TRUST_LIST,  16#0F).
-define(TYPE_STATION_ENDPOINT,             16#12).

all() ->
    [
        dir_tombstone_invalidates_realm_subtree,
        dir_tombstone_for_uncached_realm_is_noop,
        rme_tombstone_nukes_l5,
        leaf_tombstone_nukes_l5,
        rme_version_bump_invalidates_realm,
        dir_version_bump_invalidates_realm,
        frtl_version_bump_invalidates_anchored_realms,
        invalidation_leaves_other_realms_alone
    ].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    cleanup([trust_anchors, cache_records, cache_invalidate, cache_ttl_sweep,
             on_record_observed_invalidate_cache,
             on_realm_directory_changed_warm_cache]),
    {ok, _} = trust_anchors:start_link(),
    {ok, _} = cache_records:start_link(),
    {ok, _} = cache_invalidate:start_link(),
    application:set_env(resolve_mesh_names, cache_ttl_sweep_period_ms, 60000),
    {ok, _} = cache_ttl_sweep:start_link(),
    {ok, _} = on_record_observed_invalidate_cache:start_link(),
    {ok, _} = on_realm_directory_changed_warm_cache:start_link(),
    Config.

end_per_testcase(_TC, _Config) ->
    cleanup([on_realm_directory_changed_warm_cache,
             on_record_observed_invalidate_cache, cache_ttl_sweep,
             cache_invalidate, cache_records, trust_anchors]),
    application:unset_env(resolve_mesh_names, cache_ttl_sweep_period_ms),
    ok.

cleanup(Names) ->
    [case whereis(N) of
         undefined -> ok;
         Pid       -> catch gen_server:stop(Pid, normal, 1000)
     end || N <- Names],
    ok.

%%====================================================================
%% Helpers
%%====================================================================

fresh_ts() -> erlang:system_time(millisecond) + 60000.

%% Populate L1..L5 for a realm with a single chain. The realm-id →
%% realm-pk mapping in L1 is what the PMs use to reverse-lookup.
populate(RealmId, RealmPk, Mri) ->
    Ts = fresh_ts(),
    ok = cache_records:put(l1, RealmId, RealmPk,                Ts, 1),
    ok = cache_records:put(l2, RealmId, #{dir => 1},            Ts, 2),
    ok = cache_records:put(l3, {RealmId, crypto:strong_rand_bytes(32)},
                                        #{rme => 1},             Ts, 3),
    ok = cache_records:put(l4, {Mri, ?TYPE_STATION_ENDPOINT},
                                        #{leaf => 1},            Ts, 4),
    ok = cache_records:put(l5, Mri, [#{verified => 1}],         Ts, 5),
    ok.

user_mri(RealmId) ->
    {ok, M} = macula_mri:new(user, RealmId, [<<"acme">>, <<"alice">>]),
    M.

%% Build a tombstone-shaped record map (matching macula_record's
%% tombstone payload layout).
tombstone(SupKey, SupType) ->
    #{type    => ?TYPE_TOMBSTONE,
      key     => SupKey,
      payload => #{ {text, <<"superseded_key">>}  => SupKey,
                    {text, <<"superseded_type">>} => SupType,
                    {text, <<"replaced_at">>}     => erlang:system_time(millisecond),
                    {text, <<"reason">>}          => revoked }}.

%% Build an RME-shaped record map (envelope key = realm pubkey).
rme_record(RealmPk, MemberPk) ->
    #{type    => ?TYPE_REALM_MEMBER_ENDORSEMENT,
      key     => RealmPk,
      payload => #{ {text, <<"realm">>}       => RealmPk,
                    {text, <<"member_node">>} => MemberPk,
                    {text, <<"roles">>}       => [{text, <<"user">>}],
                    {text, <<"valid_from">>}  => 0,
                    {text, <<"valid_until">>} => fresh_ts() }}.

dir_record(RealmPk) ->
    #{type    => ?TYPE_REALM_DIRECTORY,
      key     => RealmPk,
      payload => #{ {text, <<"realm_id">>}  => RealmPk,
                    {text, <<"name">>}      => {text, <<"R">>},
                    {text, <<"admin_key">>} => RealmPk }}.

frtl_record(FoundationPk, TrustedRealmPks) ->
    #{type    => ?TYPE_FOUNDATION_REALM_TRUST_LIST,
      key     => FoundationPk,
      payload => #{ {text, <<"realms_trusted">>} => TrustedRealmPks,
                    {text, <<"realms_revoked">>} => [],
                    {text, <<"version">>}        => <<0:128>>,
                    {text, <<"valid_until">>}    => fresh_ts() }}.

settle() -> timer:sleep(50).   %% let casts drain

%%====================================================================
%% Tombstone handling
%%====================================================================

dir_tombstone_invalidates_realm_subtree(_Config) ->
    RealmId = <<"io.macula">>,
    RealmPk = crypto:strong_rand_bytes(32),
    Mri = user_mri(RealmId),
    populate(RealmId, RealmPk, Mri),
    {ok, _, _} = cache_records:get(l5, Mri),
    %% realm_directory tombstone: superseded_key = realm pubkey.
    ok = on_record_observed_invalidate_cache:on_record(
           ?TYPE_TOMBSTONE, tombstone(RealmPk, ?TYPE_REALM_DIRECTORY)),
    settle(),
    miss = cache_records:get(l1, RealmId),
    miss = cache_records:get(l2, RealmId),
    miss = cache_records:get(l5, Mri),
    ok.

dir_tombstone_for_uncached_realm_is_noop(_Config) ->
    %% A realm we don't have in L1 → reverse-lookup fails → no-op.
    RealmPk = crypto:strong_rand_bytes(32),
    %% Cache something for a DIFFERENT realm; it must survive.
    OtherId = <<"io.other">>, OtherPk = crypto:strong_rand_bytes(32),
    OtherMri = user_mri(OtherId),
    populate(OtherId, OtherPk, OtherMri),
    ok = on_record_observed_invalidate_cache:on_record(
           ?TYPE_TOMBSTONE, tombstone(RealmPk, ?TYPE_REALM_DIRECTORY)),
    settle(),
    {ok, _, _} = cache_records:get(l5, OtherMri),
    ok.

rme_tombstone_nukes_l5(_Config) ->
    RealmId = <<"io.macula">>, RealmPk = crypto:strong_rand_bytes(32),
    Mri = user_mri(RealmId),
    populate(RealmId, RealmPk, Mri),
    %% RME tombstone — superseded_key is a SHA-256 we can't reverse,
    %% so the coarse handler nukes all of L5. L1/L2 survive (the
    %% next chain walk re-validates them anyway).
    HashedKey = crypto:hash(sha256, <<"some_rme_key">>),
    ok = on_record_observed_invalidate_cache:on_record(
           ?TYPE_TOMBSTONE, tombstone(HashedKey, ?TYPE_REALM_MEMBER_ENDORSEMENT)),
    settle(),
    miss       = cache_records:get(l5, Mri),
    {ok, _, _} = cache_records:get(l1, RealmId),
    ok.

leaf_tombstone_nukes_l5(_Config) ->
    RealmId = <<"io.macula">>, RealmPk = crypto:strong_rand_bytes(32),
    Mri = user_mri(RealmId),
    populate(RealmId, RealmPk, Mri),
    HashedKey = crypto:hash(sha256, <<"station_endpoint", RealmPk/binary>>),
    ok = on_record_observed_invalidate_cache:on_record(
           ?TYPE_TOMBSTONE, tombstone(HashedKey, ?TYPE_STATION_ENDPOINT)),
    settle(),
    miss = cache_records:get(l5, Mri),
    ok.

%%====================================================================
%% Version-bump handling
%%====================================================================

rme_version_bump_invalidates_realm(_Config) ->
    RealmId = <<"io.macula">>, RealmPk = crypto:strong_rand_bytes(32),
    Mri = user_mri(RealmId),
    populate(RealmId, RealmPk, Mri),
    ok = on_record_observed_invalidate_cache:on_record(
           ?TYPE_REALM_MEMBER_ENDORSEMENT,
           rme_record(RealmPk, crypto:strong_rand_bytes(32))),
    settle(),
    miss = cache_records:get(l1, RealmId),
    miss = cache_records:get(l5, Mri),
    ok.

dir_version_bump_invalidates_realm(_Config) ->
    RealmId = <<"io.macula">>, RealmPk = crypto:strong_rand_bytes(32),
    Mri = user_mri(RealmId),
    populate(RealmId, RealmPk, Mri),
    %% realm_directory version bump → handled by the warm-cache PM.
    ok = on_realm_directory_changed_warm_cache:on_record(
           ?TYPE_REALM_DIRECTORY, dir_record(RealmPk)),
    settle(),
    miss = cache_records:get(l1, RealmId),
    miss = cache_records:get(l5, Mri),
    ok.

frtl_version_bump_invalidates_anchored_realms(_Config) ->
    FoundationPk = crypto:strong_rand_bytes(32),
    RealmId1 = <<"io.a">>, RealmPk1 = crypto:strong_rand_bytes(32),
    RealmId2 = <<"io.b">>, RealmPk2 = crypto:strong_rand_bytes(32),
    %% Both realms anchored to the same foundation.
    ok = trust_anchors:put(RealmId1, FoundationPk),
    ok = trust_anchors:put(RealmId2, FoundationPk),
    M1 = user_mri(RealmId1), M2 = user_mri(RealmId2),
    populate(RealmId1, RealmPk1, M1),
    populate(RealmId2, RealmPk2, M2),
    ok = on_realm_directory_changed_warm_cache:on_record(
           ?TYPE_FOUNDATION_REALM_TRUST_LIST,
           frtl_record(FoundationPk, [RealmPk1, RealmPk2])),
    settle(),
    miss = cache_records:get(l5, M1),
    miss = cache_records:get(l5, M2),
    ok.

invalidation_leaves_other_realms_alone(_Config) ->
    RealmId1 = <<"io.target">>, RealmPk1 = crypto:strong_rand_bytes(32),
    RealmId2 = <<"io.bystander">>, RealmPk2 = crypto:strong_rand_bytes(32),
    M1 = user_mri(RealmId1), M2 = user_mri(RealmId2),
    populate(RealmId1, RealmPk1, M1),
    populate(RealmId2, RealmPk2, M2),
    %% Tombstone for realm 1's directory.
    ok = on_record_observed_invalidate_cache:on_record(
           ?TYPE_TOMBSTONE, tombstone(RealmPk1, ?TYPE_REALM_DIRECTORY)),
    settle(),
    miss       = cache_records:get(l5, M1),
    {ok, _, _} = cache_records:get(l1, RealmId2),
    {ok, _, _} = cache_records:get(l5, M2),
    ok.
