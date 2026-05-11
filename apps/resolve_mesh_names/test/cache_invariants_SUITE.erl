%%% @doc CT suite for cache_records + cache_invalidate +
%%% cache_ttl_sweep. PLAN PART1 §5.3 + §6.
%%%
%%% Coverage:
%%%   - get/put round-trip per layer
%%%   - get returns miss for stale entries (TTL respected)
%%%   - delete is idempotent
%%%   - all_keys / size diagnostics
%%%   - cascade invalidation:
%%%     * by_realm (L1 → L2/L3/L4/L5)
%%%     * by_member_path (L3 → L4/L5)
%%%     * by_mri (L4 → L5)
%%%   - station MRIs don't tie to realm-cascade rules
%%%   - all/0 nukes everything
%%%   - ttl_sweep evicts stale entries
%%% @end
-module(cache_invariants_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    get_returns_miss_when_empty/1,
    put_then_get_roundtrip_per_layer/1,
    get_returns_miss_for_stale/1,
    delete_is_idempotent/1,
    all_keys_returns_keys/1,
    cascade_l1_invalidates_realm_subtree/1,
    cascade_l1_leaves_other_realms_alone/1,
    cascade_l3_invalidates_path_descendants/1,
    cascade_l4_invalidates_l5_only/1,
    cascade_by_mri_invalidates_l4_and_l5/1,
    station_mri_not_affected_by_realm_cascade/1,
    all_nukes_every_layer/1,
    ttl_sweep_evicts_stale_entries/1,
    ttl_sweep_leaves_fresh_entries/1
]).

all() ->
    [
        get_returns_miss_when_empty,
        put_then_get_roundtrip_per_layer,
        get_returns_miss_for_stale,
        delete_is_idempotent,
        all_keys_returns_keys,
        cascade_l1_invalidates_realm_subtree,
        cascade_l1_leaves_other_realms_alone,
        cascade_l3_invalidates_path_descendants,
        cascade_l4_invalidates_l5_only,
        cascade_by_mri_invalidates_l4_and_l5,
        station_mri_not_affected_by_realm_cascade,
        all_nukes_every_layer,
        ttl_sweep_evicts_stale_entries,
        ttl_sweep_leaves_fresh_entries
    ].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    {ok, P1} = cache_records:start_link(),     unlink(P1),
    {ok, P2} = cache_invalidate:start_link(),  unlink(P2),
    %% Use a long sweep period so the periodic timer doesn't
    %% interfere with deterministic tests; trigger sweeps explicitly
    %% via sweep_now/0.
    application:set_env(resolve_mesh_names, cache_ttl_sweep_period_ms, 60000),
    {ok, P3} = cache_ttl_sweep:start_link(),   unlink(P3),
    [{pids, [P1, P2, P3]} | Config].

end_per_testcase(_TC, Config) ->
    Pids = ?config(pids, Config),
    [shutdown(P) || P <- Pids],
    application:unset_env(resolve_mesh_names, cache_ttl_sweep_period_ms),
    ok.

shutdown(Pid) when is_pid(Pid) ->
    case is_process_alive(Pid) of
        true  -> exit(Pid, shutdown), wait_dead(Pid, 100);
        false -> ok
    end.

wait_dead(_Pid, 0) -> ok;
wait_dead(Pid, N) ->
    case is_process_alive(Pid) of
        false -> ok;
        true  -> timer:sleep(10), wait_dead(Pid, N - 1)
    end.

%% Helpers
fresh_ts() -> erlang:system_time(millisecond) + 60000.   %% 60s in future
stale_ts() -> erlang:system_time(millisecond) - 1.        %% already past

%% Plain user MRI for cascade tests
user_mri(Realm) ->
    {ok, M} = macula_mri:new(user, Realm, [<<"acme">>, <<"alice">>]),
    M.

%%====================================================================
%% Basic ops
%%====================================================================

get_returns_miss_when_empty(_Config) ->
    miss = cache_records:get(l1, <<"io.macula">>),
    miss = cache_records:get(l2, <<"io.macula">>),
    miss = cache_records:get(l5, <<"mri:user:io.macula/acme/alice">>),
    ok.

put_then_get_roundtrip_per_layer(_Config) ->
    Ts = fresh_ts(),
    Pubkey = binary:copy(<<1>>, 32),
    Mri    = user_mri(<<"io.macula">>),
    L4Key  = {Mri, station_endpoint},
    ok = cache_records:put(l1, <<"io.macula">>,    Pubkey,           Ts, 1),
    ok = cache_records:put(l2, <<"io.macula">>,    #{dir => 1},      Ts, 2),
    ok = cache_records:put(l3, {<<"io.macula">>, [<<"acme">>, <<"alice">>]},
                                                    #{rme => 1},     Ts, 3),
    ok = cache_records:put(l4, L4Key,              #{leaf => 1},     Ts, 4),
    ok = cache_records:put(l5, Mri,                [#{verified => 1}], Ts, 5),
    {ok, Pubkey, _}        = cache_records:get(l1, <<"io.macula">>),
    {ok, #{dir := 1}, _}   = cache_records:get(l2, <<"io.macula">>),
    {ok, #{rme := 1}, _}   = cache_records:get(l3, {<<"io.macula">>, [<<"acme">>, <<"alice">>]}),
    {ok, #{leaf := 1}, _}  = cache_records:get(l4, L4Key),
    {ok, [#{verified := 1}], _} = cache_records:get(l5, Mri),
    ok.

get_returns_miss_for_stale(_Config) ->
    Mri = user_mri(<<"io.macula">>),
    ok = cache_records:put(l5, Mri, [#{}], stale_ts(), 1),
    miss = cache_records:get(l5, Mri),
    ok.

delete_is_idempotent(_Config) ->
    ok = cache_records:delete(l1, <<"io.does.not.exist">>),
    ok = cache_records:put(l1, <<"io.real">>, <<0:256>>, fresh_ts(), 1),
    ok = cache_records:delete(l1, <<"io.real">>),
    ok = cache_records:delete(l1, <<"io.real">>),  %% second delete = no-op
    miss = cache_records:get(l1, <<"io.real">>),
    ok.

all_keys_returns_keys(_Config) ->
    ok = cache_records:put(l1, <<"io.a">>, <<0:256>>, fresh_ts(), 1),
    ok = cache_records:put(l1, <<"io.b">>, <<0:256>>, fresh_ts(), 2),
    Keys = lists:sort(cache_records:all_keys(l1)),
    [<<"io.a">>, <<"io.b">>] = Keys,
    2 = cache_records:size(l1),
    ok.

%%====================================================================
%% Cascades
%%====================================================================

cascade_l1_invalidates_realm_subtree(_Config) ->
    Realm = <<"io.macula">>,
    Mri   = user_mri(Realm),
    populate_full_chain(Realm, Mri),
    %% Sanity
    {ok, _, _} = cache_records:get(l5, Mri),
    %% Trigger cascade via L1 invalidation
    ok = cache_invalidate:by_realm(Realm),
    miss = cache_records:get(l1, Realm),
    miss = cache_records:get(l2, Realm),
    miss = cache_records:get(l3, {Realm, [<<"acme">>, <<"alice">>]}),
    miss = cache_records:get(l4, {Mri, station_endpoint}),
    miss = cache_records:get(l5, Mri),
    ok.

cascade_l1_leaves_other_realms_alone(_Config) ->
    R1 = <<"io.macula">>,
    R2 = <<"io.beamcampus">>,
    M1 = user_mri(R1),
    M2 = user_mri(R2),
    populate_full_chain(R1, M1),
    populate_full_chain(R2, M2),
    ok = cache_invalidate:by_realm(R1),
    %% R1 wiped
    miss = cache_records:get(l5, M1),
    %% R2 untouched
    {ok, _, _} = cache_records:get(l1, R2),
    {ok, _, _} = cache_records:get(l5, M2),
    ok.

cascade_l3_invalidates_path_descendants(_Config) ->
    Realm = <<"io.macula">>,
    Path  = [<<"acme">>, <<"alice">>],
    Mri   = user_mri(Realm),
    populate_full_chain(Realm, Mri),
    %% L1+L2 should survive an L3-scoped invalidation
    ok = cache_invalidate:by_member_path(Realm, Path),
    {ok, _, _} = cache_records:get(l1, Realm),
    {ok, _, _} = cache_records:get(l2, Realm),
    miss       = cache_records:get(l3, {Realm, Path}),
    miss       = cache_records:get(l4, {Mri, station_endpoint}),
    miss       = cache_records:get(l5, Mri),
    ok.

cascade_l4_invalidates_l5_only(_Config) ->
    Realm = <<"io.macula">>,
    Mri   = user_mri(Realm),
    populate_full_chain(Realm, Mri),
    ok = cache_invalidate:by_key(l4, {Mri, station_endpoint}),
    %% L1/L2/L3 untouched
    {ok, _, _} = cache_records:get(l1, Realm),
    {ok, _, _} = cache_records:get(l2, Realm),
    {ok, _, _} = cache_records:get(l3, {Realm, [<<"acme">>, <<"alice">>]}),
    miss       = cache_records:get(l4, {Mri, station_endpoint}),
    miss       = cache_records:get(l5, Mri),
    ok.

cascade_by_mri_invalidates_l4_and_l5(_Config) ->
    Realm = <<"io.macula">>,
    Mri   = user_mri(Realm),
    populate_full_chain(Realm, Mri),
    %% by_mri should also nuke OTHER record-types' L4 entries
    ok = cache_records:put(l4, {Mri, address_pubkey_map},
                           #{leaf => 2}, fresh_ts(), 99),
    ok = cache_invalidate:by_mri(Mri),
    miss = cache_records:get(l4, {Mri, station_endpoint}),
    miss = cache_records:get(l4, {Mri, address_pubkey_map}),
    miss = cache_records:get(l5, Mri),
    %% Upstream layers untouched
    {ok, _, _} = cache_records:get(l1, Realm),
    {ok, _, _} = cache_records:get(l2, Realm),
    ok.

station_mri_not_affected_by_realm_cascade(_Config) ->
    %% Station MRIs have no realm; they shouldn't be evicted by
    %% a realm-scoped cascade.
    Pubkey = crypto:strong_rand_bytes(32),
    Z32    = macula_z32:encode(Pubkey),
    StationMri = <<"mri:station:", Z32/binary>>,
    ok = cache_records:put(l5, StationMri, [#{station => 1}], fresh_ts(), 1),
    ok = cache_invalidate:by_realm(<<"io.macula">>),
    %% Station entry survives
    {ok, _, _} = cache_records:get(l5, StationMri),
    ok.

all_nukes_every_layer(_Config) ->
    Realm = <<"io.macula">>,
    Mri   = user_mri(Realm),
    populate_full_chain(Realm, Mri),
    ok = cache_invalidate:all(),
    0 = cache_records:size(l1),
    0 = cache_records:size(l2),
    0 = cache_records:size(l3),
    0 = cache_records:size(l4),
    0 = cache_records:size(l5),
    ok.

%%====================================================================
%% TTL sweep
%%====================================================================

ttl_sweep_evicts_stale_entries(_Config) ->
    Mri = user_mri(<<"io.macula">>),
    ok = cache_records:put(l5, Mri, [#{}], stale_ts(), 1),
    ok = cache_records:put(l5, <<"mri:user:io.macula/acme/bob">>,
                           [#{}], stale_ts(), 2),
    2 = cache_records:size(l5),
    {ok, Evicted} = cache_ttl_sweep:sweep_now(),
    true = (Evicted >= 2),
    0 = cache_records:size(l5),
    ok.

ttl_sweep_leaves_fresh_entries(_Config) ->
    Mri1 = user_mri(<<"io.macula">>),
    Mri2 = <<"mri:user:io.macula/acme/bob">>,
    ok = cache_records:put(l5, Mri1, [#{}], fresh_ts(), 1),
    ok = cache_records:put(l5, Mri2, [#{}], stale_ts(), 2),
    {ok, _Evicted} = cache_ttl_sweep:sweep_now(),
    {ok, _, _} = cache_records:get(l5, Mri1),
    miss = cache_records:get(l5, Mri2),
    ok.

%%====================================================================
%% Test helpers
%%====================================================================

populate_full_chain(Realm, Mri) ->
    Ts = fresh_ts(),
    ok = cache_records:put(l1, Realm, binary:copy(<<1>>, 32), Ts, 1),
    ok = cache_records:put(l2, Realm, #{dir => 1},            Ts, 2),
    ok = cache_records:put(l3, {Realm, [<<"acme">>, <<"alice">>]},
                                    #{rme => 1},               Ts, 3),
    ok = cache_records:put(l4, {Mri, station_endpoint},
                                    #{leaf => 1},              Ts, 4),
    ok = cache_records:put(l5, Mri, [#{verified => 1}],        Ts, 5),
    ok.
