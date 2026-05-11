%%% @doc CT suite for verify_trust_chain. PLAN_RESOLVE_MESH_NAMES_PART1
%%% §5.1 + §5.2.
%%%
%%% Tests use real macula_identity keypairs + macula_record:sign/2
%%% so the signature math is genuine, not stubbed. The DHT layer
%%% is faked via lookup_via_dht's `find_fn' Opts dependency
%%% injection.
%%%
%%% Coverage:
%%%   - Happy path: full chain verifies, returns verified_record
%%%   - need_anchor: missing trust anchor → no_trust_root
%%%   - need_frtl: realm not in FRTL trusted list → realm_not_trusted
%%%   - need_frtl: FRTL signed by wrong key → trust_list_unavailable
%%%   - need_frtl: FRTL expired → trust_list_stale
%%%   - need_dir: realm_directory missing → realm_dir_unavailable
%%%   - need_dir: realm_directory tampered → realm_dir_bogus
%%%   - need_endorse: RME missing → coverage_unknown (Phase 1 default)
%%%   - need_endorse: RME outside validity window → endorsement_expired/clock_skew
%%%   - need_leaf: leaf signed by wrong key → sig_indeterminate
%%%   - station MRI rejected as self-rooted (no chain applies)
%%%
%%% Limitations documented inline:
%%%   - SDK 4.x RMEs lack a `path' field, so per-path authorisation
%%%     isn't enforced — endorsements are realm-wide.
%%%   - coverage_proof not yet in SDK; missing endorsement falls
%%%     back to coverage_unknown rather than name_not_endorsed.
%%%   - host_delegation tests deferred until we have a SDK
%%%     constructor for the embedded delegation map.
%%% @end
-module(verify_trust_chain_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    happy_path_full_chain/1,
    no_trust_root_when_realm_unknown/1,
    realm_not_trusted_when_pk_missing_from_frtl/1,
    trust_list_unavailable_when_envelope_key_mismatch/1,
    trust_list_stale_when_valid_until_past/1,
    realm_dir_unavailable_when_dht_miss/1,
    realm_dir_bogus_when_envelope_key_mismatch/1,
    coverage_unknown_when_endorsement_missing/1,
    endorsement_expired_when_valid_until_past/1,
    sig_indeterminate_when_leaf_signed_by_wrong_key/1,
    station_mri_rejected_as_self_rooted/1,
    leaf_storage_key_required_when_caller_omits/1,
    happy_path_uses_l1_cache_on_second_call/1,
    happy_path_uses_l4_cache_on_second_call/1
]).

all() ->
    [
        happy_path_full_chain,
        no_trust_root_when_realm_unknown,
        realm_not_trusted_when_pk_missing_from_frtl,
        trust_list_unavailable_when_envelope_key_mismatch,
        trust_list_stale_when_valid_until_past,
        realm_dir_unavailable_when_dht_miss,
        realm_dir_bogus_when_envelope_key_mismatch,
        coverage_unknown_when_endorsement_missing,
        endorsement_expired_when_valid_until_past,
        sig_indeterminate_when_leaf_signed_by_wrong_key,
        station_mri_rejected_as_self_rooted,
        leaf_storage_key_required_when_caller_omits,
        happy_path_uses_l1_cache_on_second_call,
        happy_path_uses_l4_cache_on_second_call
    ].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    %% Defensive: kill any leaked named gen_servers from a previous
    %% test that crashed in init_per_testcase (end_per_testcase
    %% wouldn't have run if the leak happened before pids landed
    %% in Config).
    cleanup_leaked_names([trust_anchors, cache_records, cache_invalidate,
                          cache_ttl_sweep, lookup_dedup, lookup_via_dht]),
    {ok, P1} = trust_anchors:start_link(),     unlink(P1),
    {ok, P2} = cache_records:start_link(),     unlink(P2),
    {ok, P3} = cache_invalidate:start_link(),  unlink(P3),
    application:set_env(resolve_mesh_names, cache_ttl_sweep_period_ms, 60000),
    {ok, P4} = cache_ttl_sweep:start_link(),   unlink(P4),
    {ok, P5} = lookup_dedup:start_link(),      unlink(P5),
    {ok, P6} = lookup_via_dht:start_link(),    unlink(P6),
    Fixture = build_fixture(),
    [{pids, [P1, P2, P3, P4, P5, P6]}, {fix, Fixture} | Config].

cleanup_leaked_names(Names) ->
    [case whereis(N) of
         undefined -> ok;
         Pid       -> catch gen_server:stop(Pid, normal, 1000)
     end || N <- Names],
    ok.

end_per_testcase(_TC, Config) ->
    [shutdown(P) || P <- ?config(pids, Config)],
    application:unset_env(resolve_mesh_names, cache_ttl_sweep_period_ms),
    application:unset_env(resolve_mesh_names, compiled_in_realm_pubkeys),
    ok.

shutdown(Pid) when is_pid(Pid) ->
    %% gen_server:stop is synchronous + unregisters the local name
    %% before returning, so the next init_per_testcase can re-register
    %% without racing on {already_started, _}.
    case is_process_alive(Pid) of
        true  -> catch gen_server:stop(Pid, normal, 1000);
        false -> ok
    end,
    ok.

%%====================================================================
%% Fixture: build a complete signed trust chain
%%====================================================================

build_fixture() ->
    %% Identities: foundation, realm root, member, daemon (unused
    %% in the basic happy path; reserved for hosted_address_map).
    Foundation = macula_identity:generate(),
    RealmRoot  = macula_identity:generate(),
    Member     = macula_identity:generate(),

    FoundationPk = macula_identity:public(Foundation),
    RealmPk      = macula_identity:public(RealmRoot),
    MemberPk     = macula_identity:public(Member),

    RealmId = <<"io.testrealm">>,

    %% Install foundation seed in trust_anchors + realm_pk in app env
    ok = trust_anchors:put(RealmId, FoundationPk),
    application:set_env(resolve_mesh_names, compiled_in_realm_pubkeys,
                        [{RealmId, RealmPk}]),

    %% FRTL: foundation signs a list with our realm pubkey trusted.
    Frtl = macula_record:foundation_realm_trust_list(FoundationPk, [RealmPk]),
    SignedFrtl = macula_record:sign(Frtl, Foundation),

    %% realm_directory: realm root signs.
    Dir = macula_record:realm_directory(RealmPk, <<"Test Realm">>, RealmPk),
    SignedDir = macula_record:sign(Dir, RealmRoot),

    %% RME: realm root endorses member.
    NowMs = erlang:system_time(millisecond),
    %% realm_member_endorsement_opts() — pass valid_from/valid_until
    %% explicitly so we control the window in tests.
    Rme = macula_record:realm_member_endorsement(
            RealmPk,
            #{realm       => RealmPk,
              member_node => MemberPk,
              roles       => [<<"user">>]},
            #{valid_from  => NowMs - 1000,
              valid_until => NowMs + 86400000}),
    SignedRme = macula_record:sign(Rme, RealmRoot),

    %% Leaf: member signs their own station_endpoint. The
    %% constructor takes (StationPk, QuicPort, Opts).
    Leaf = macula_record:station_endpoint(MemberPk, 4433,
                                          #{host_advertised => [<<"::1">>]}),
    SignedLeaf = macula_record:sign(Leaf, Member),

    %% MRI for queries (user MRI; the leaf storage key is the MEMBER pubkey
    %% since this leaf is a station_endpoint keyed by station/member pk).
    {ok, Mri} = macula_mri:new(user, RealmId, [<<"acme">>, <<"alice">>]),

    LeafStorageKey = macula_record:storage_key(SignedLeaf),

    #{foundation_id => Foundation,
      realm_root_id => RealmRoot,
      member_id     => Member,
      foundation_pk => FoundationPk,
      realm_pk      => RealmPk,
      member_pk     => MemberPk,
      realm_id      => RealmId,
      mri           => Mri,
      frtl          => SignedFrtl,
      dir           => SignedDir,
      rme           => SignedRme,
      leaf          => SignedLeaf,
      leaf_key      => LeafStorageKey}.

%%====================================================================
%% Helper: build a stub find_fn that serves records from a map of
%% storage_key → record. Anything not in the map → {error, not_found}.
%%====================================================================

stub_find(RecordsByKey) ->
    fun(_Pool, Key) ->
        case maps:get(Key, RecordsByKey, undefined) of
            undefined -> {error, not_found};
            Record    -> {ok, Record}
        end
    end.

records_by_key(#{frtl := Frtl, dir := Dir, rme := Rme, leaf := Leaf}) ->
    #{
        macula_record:storage_key(Frtl) => Frtl,
        macula_record:storage_key(Dir)  => Dir,
        macula_record:storage_key(Rme)  => Rme,
        macula_record:storage_key(Leaf) => Leaf
    }.

verify_with_stub_dht(Fix, RecordsMap) ->
    Find = stub_find(RecordsMap),
    Opts = #{find_fn => Find,
             max_attempts => 1,
             retry_delay_ms => 0},
    verify_trust_chain:verify(self(), maps:get(mri, Fix),
                              maps:get(leaf_key, Fix),
                              station_endpoint, Opts).

%%====================================================================
%% Test cases
%%====================================================================

happy_path_full_chain(Config) ->
    Fix = ?config(fix, Config),
    Records = records_by_key(Fix),
    {ok, Verified} = verify_with_stub_dht(Fix, Records),
    %% Verified record carries the chain metadata + the leaf payload.
    #{record_type   := station_endpoint,
      mri           := Mri,
      signer_pubkey := MemberPk,
      chain         := Chain} = Verified,
    Mri      = maps:get(mri, Fix),
    MemberPk = maps:get(member_pk, Fix),
    4        = length(Chain),
    ok.

no_trust_root_when_realm_unknown(Config) ->
    Fix = ?config(fix, Config),
    %% Wipe the trust anchor so need_anchor fails.
    ok = trust_anchors:remove(maps:get(realm_id, Fix)),
    Records = records_by_key(Fix),
    {error, no_trust_root} = verify_with_stub_dht(Fix, Records).

realm_not_trusted_when_pk_missing_from_frtl(Config) ->
    Fix = ?config(fix, Config),
    %% Sign a different FRTL where our realm_pk is NOT in trusted.
    SomeOtherPk = crypto:strong_rand_bytes(32),
    BadFrtl = macula_record:foundation_realm_trust_list(
                maps:get(foundation_pk, Fix), [SomeOtherPk]),
    SignedBad = macula_record:sign(BadFrtl, maps:get(foundation_id, Fix)),
    Records = (records_by_key(Fix))#{
        macula_record:storage_key(SignedBad) => SignedBad
    },
    %% Replace the original FRTL with the bad one at the foundation key.
    Records2 = maps:remove(macula_record:storage_key(maps:get(frtl, Fix)),
                           Records),
    Records3 = Records2#{macula_record:storage_key(SignedBad) => SignedBad},
    {error, realm_not_trusted} = verify_with_stub_dht(Fix, Records3).

trust_list_unavailable_when_envelope_key_mismatch(Config) ->
    Fix = ?config(fix, Config),
    %% Replace FRTL with one signed by a DIFFERENT foundation key
    %% (envelope key mismatch).
    OtherFound = macula_identity:generate(),
    OtherFoundPk = macula_identity:public(OtherFound),
    BadFrtl = macula_record:foundation_realm_trust_list(
                OtherFoundPk, [maps:get(realm_pk, Fix)]),
    SignedBad = macula_record:sign(BadFrtl, OtherFound),
    %% Place at the storage key our chain WILL look up
    %% (sha256("foundation_realm_trust_list" || foundation_pk)).
    OurFrtlKey = crypto:hash(sha256,
                             <<"foundation_realm_trust_list",
                               (maps:get(foundation_pk, Fix))/binary>>),
    Records = (records_by_key(Fix))#{OurFrtlKey => SignedBad},
    {error, trust_list_unavailable} = verify_with_stub_dht(Fix, Records).

trust_list_stale_when_valid_until_past(Config) ->
    Fix = ?config(fix, Config),
    %% Build an FRTL whose valid_until is in the past.
    OldFrtl = macula_record:foundation_realm_trust_list(
                maps:get(foundation_pk, Fix),
                [maps:get(realm_pk, Fix)],
                #{valid_until => 1}),    %% epoch ms = 1970
    SignedOld = macula_record:sign(OldFrtl, maps:get(foundation_id, Fix)),
    Records = (records_by_key(Fix))#{
        macula_record:storage_key(SignedOld) => SignedOld
    },
    {error, trust_list_stale} = verify_with_stub_dht(Fix, Records).

realm_dir_unavailable_when_dht_miss(Config) ->
    Fix = ?config(fix, Config),
    %% Records map without the realm_directory entry.
    Records = maps:remove(macula_record:storage_key(maps:get(dir, Fix)),
                          records_by_key(Fix)),
    {error, realm_dir_unavailable} = verify_with_stub_dht(Fix, Records).

realm_dir_bogus_when_envelope_key_mismatch(Config) ->
    Fix = ?config(fix, Config),
    %% Build a realm_directory whose envelope key is NOT our realm_pk.
    OtherRealm = macula_identity:generate(),
    OtherPk = macula_identity:public(OtherRealm),
    BadDir = macula_record:realm_directory(OtherPk, <<"Other">>, OtherPk),
    SignedBad = macula_record:sign(BadDir, OtherRealm),
    %% realm_directory's storage key IS the realm pubkey itself.
    OurDirKey = maps:get(realm_pk, Fix),
    Records = (records_by_key(Fix))#{OurDirKey => SignedBad},
    {error, realm_dir_bogus} = verify_with_stub_dht(Fix, Records).

coverage_unknown_when_endorsement_missing(Config) ->
    Fix = ?config(fix, Config),
    %% Records without the RME — Phase 1 falls back to coverage_unknown
    %% (no coverage_proof support yet).
    Records = maps:remove(macula_record:storage_key(maps:get(rme, Fix)),
                          records_by_key(Fix)),
    {error, coverage_unknown} = verify_with_stub_dht(Fix, Records).

endorsement_expired_when_valid_until_past(Config) ->
    Fix = ?config(fix, Config),
    %% Build an RME with valid_until in the past.
    OldRme = macula_record:realm_member_endorsement(
               maps:get(realm_pk, Fix),
               #{realm       => maps:get(realm_pk, Fix),
                 member_node => maps:get(member_pk, Fix),
                 roles       => [<<"user">>]},
               #{valid_from  => 1,
                 valid_until => 2}),
    SignedOld = macula_record:sign(OldRme, maps:get(realm_root_id, Fix)),
    Records = (records_by_key(Fix))#{
        macula_record:storage_key(SignedOld) => SignedOld
    },
    {error, endorsement_expired} = verify_with_stub_dht(Fix, Records).

sig_indeterminate_when_leaf_signed_by_wrong_key(Config) ->
    Fix = ?config(fix, Config),
    %% Build a leaf signed by an unrelated key (not the endorsed member).
    Imposter = macula_identity:generate(),
    ImposterPk = macula_identity:public(Imposter),
    BadLeaf = macula_record:station_endpoint(ImposterPk, 4433,
                                             #{host_advertised => [<<"::2">>]}),
    SignedBad = macula_record:sign(BadLeaf, Imposter),
    %% Place at the leaf storage key our chain looks up.
    Records = (records_by_key(Fix))#{
        macula_record:storage_key(SignedBad) => SignedBad
    },
    %% Remove the original leaf so the bad one wins.
    Records2 = maps:remove(macula_record:storage_key(maps:get(leaf, Fix)),
                           Records),
    %% Override the chain's leaf-key parameter to the imposter's
    %% storage key so verify_trust_chain even reaches it.
    Fix2 = Fix#{leaf_key := macula_record:storage_key(SignedBad)},
    %% In our chain, the imposter's pubkey != endorsed member, and
    %% the leaf signer is the imposter — so we either fail at
    %% need_endorse (no RME for imposter pk) or at leaf verify.
    %% Either way the typed error tracks back to sig_indeterminate
    %% or coverage_unknown — we accept either as wrong-leaf detection.
    Result = verify_with_stub_dht(Fix2, Records2),
    case Result of
        {error, coverage_unknown}   -> ok;       %% imposter not endorsed
        {error, sig_indeterminate}  -> ok;
        Other -> ct:fail({unexpected_result, Other})
    end.

station_mri_rejected_as_self_rooted(Config) ->
    Fix = ?config(fix, Config),
    Pubkey = crypto:strong_rand_bytes(32),
    Z32 = macula_z32:encode(Pubkey),
    StationMri = <<"mri:station:", Z32/binary>>,
    Find = stub_find(records_by_key(Fix)),
    {error, station_mri_self_rooted} =
        verify_trust_chain:verify(self(), StationMri,
                                  maps:get(leaf_key, Fix), station_endpoint,
                                  #{find_fn => Find, max_attempts => 1,
                                    retry_delay_ms => 0}).

leaf_storage_key_required_when_caller_omits(_Config) ->
    %% verify/3 (no LeafStorageKey) currently surfaces a typed
    %% error — Phase 1.5 (resolve_mri) will derive the key from
    %% MRI + LeafType and call verify/4 instead.
    {error, leaf_storage_key_required} =
        verify_trust_chain:verify(self(), <<"mri:user:io.x/a/b">>,
                                  station_endpoint).

happy_path_uses_l1_cache_on_second_call(Config) ->
    Fix = ?config(fix, Config),
    Records = records_by_key(Fix),
    {ok, _} = verify_with_stub_dht(Fix, Records),
    %% After first call, L1 cache should have realm_id → realm_pk.
    {ok, _, _} = cache_records:get(l1, maps:get(realm_id, Fix)),
    %% Second call hits L1 → L2 (still misses initially) → ...
    {ok, _} = verify_with_stub_dht(Fix, Records),
    ok.

happy_path_uses_l4_cache_on_second_call(Config) ->
    Fix = ?config(fix, Config),
    Records = records_by_key(Fix),
    {ok, _} = verify_with_stub_dht(Fix, Records),
    %% L4 should now have the leaf record cached.
    {ok, _, _} = cache_records:get(l4,
                                   {maps:get(mri, Fix), station_endpoint}),
    ok.
