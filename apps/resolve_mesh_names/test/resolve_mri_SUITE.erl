%%% @doc CT suite for resolve_mri. PLAN_RESOLVE_MESH_NAMES_PART1 §7.1.
%%%
%%% Coverage:
%%%   - station MRI: fetch + verify self-signed station_endpoint
%%%   - station MRI: wrong signer → sig_indeterminate
%%%   - station MRI: envelope-key mismatch → sig_indeterminate
%%%   - station MRI: DHT miss → station_not_announced
%%%   - user/app/etc MRI → {not_resolvable_yet, Type}
%%%   - malformed MRI → malformed_mri
%%%   - L5 cache hit on second resolve (no DHT call)
%%%   - refresh invalidates + re-resolves
%%%   - proc MRI: full trust-chain resolution → verified record
%%%
%%% Uses real macula_identity keypairs + macula_record:sign/2;
%%% the DHT layer is faked via Opts.find_fn dependency injection.
%%% @end
-module(resolve_mri_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    station_resolves_self_signed_endpoint/1,
    station_wrong_signer_is_sig_indeterminate/1,
    station_envelope_key_mismatch_is_sig_indeterminate/1,
    station_dht_miss_is_not_announced/1,
    user_mri_not_resolvable_yet/1,
    malformed_mri_rejected/1,
    l5_cache_hit_skips_dht_on_second_resolve/1,
    refresh_invalidates_and_reresolves/1,
    proc_mri_resolves_via_trust_chain/1
]).

all() ->
    [
        station_resolves_self_signed_endpoint,
        station_wrong_signer_is_sig_indeterminate,
        station_envelope_key_mismatch_is_sig_indeterminate,
        station_dht_miss_is_not_announced,
        user_mri_not_resolvable_yet,
        malformed_mri_rejected,
        l5_cache_hit_skips_dht_on_second_resolve,
        refresh_invalidates_and_reresolves,
        proc_mri_resolves_via_trust_chain
    ].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    cleanup_leaked([trust_anchors, cache_records, cache_invalidate,
                    cache_ttl_sweep, lookup_dedup, lookup_via_dht,
                    verify_trust_chain, resolve_mri]),
    {ok, _} = trust_anchors:start_link(),
    {ok, _} = cache_records:start_link(),
    {ok, _} = cache_invalidate:start_link(),
    application:set_env(resolve_mesh_names, cache_ttl_sweep_period_ms, 60000),
    {ok, _} = cache_ttl_sweep:start_link(),
    {ok, _} = lookup_dedup:start_link(),
    {ok, _} = lookup_via_dht:start_link(),
    {ok, _} = verify_trust_chain:start_link(),
    {ok, _} = resolve_mri:start_link(),
    Config.

end_per_testcase(_TC, _Config) ->
    cleanup_leaked([resolve_mri, verify_trust_chain, lookup_via_dht,
                    lookup_dedup, cache_ttl_sweep, cache_invalidate,
                    cache_records, trust_anchors]),
    application:unset_env(resolve_mesh_names, cache_ttl_sweep_period_ms),
    application:unset_env(resolve_mesh_names, compiled_in_realm_pubkeys),
    ok.

cleanup_leaked(Names) ->
    [case whereis(N) of
         undefined -> ok;
         Pid       -> catch gen_server:stop(Pid, normal, 1000)
     end || N <- Names],
    ok.

%%====================================================================
%% Fixtures
%%====================================================================

%% A signed station_endpoint where the station IS the signer.
make_station_fixture() ->
    Station   = macula_identity:generate(),
    StationPk = macula_identity:public(Station),
    Z32       = macula_z32:encode(StationPk),
    Mri       = <<"mri:station:", Z32/binary>>,
    Record    = macula_record:sign(
                  macula_record:station_endpoint(StationPk, 4433,
                                                 #{host_advertised => [<<"::1">>]}),
                  Station),
    StorageKey = macula_record:storage_key(Record),
    #{station_id => Station, station_pk => StationPk,
      mri => Mri, record => Record, storage_key => StorageKey}.

stub_find(Map) ->
    fun(_Pool, K) ->
        case maps:get(K, Map, undefined) of
            undefined -> {error, not_found};
            Rec       -> {ok, Rec}
        end
    end.

opts(Find) ->
    #{find_fn => Find, max_attempts => 1, retry_delay_ms => 0}.

%%====================================================================
%% Station MRI tests
%%====================================================================

station_resolves_self_signed_endpoint(_Config) ->
    F = make_station_fixture(),
    Find = stub_find(#{maps:get(storage_key, F) => maps:get(record, F)}),
    {ok, [VR]} = resolve_mri:resolve(self(), maps:get(mri, F), opts(Find)),
    #{record_type   := station_endpoint,
      mri           := Mri,
      signer_pubkey := Pk,
      chain         := [#{type := self_rooted, pubkey := Pk}]} = VR,
    Mri = maps:get(mri, F),
    Pk  = maps:get(station_pk, F),
    ok.

station_wrong_signer_is_sig_indeterminate(_Config) ->
    F = make_station_fixture(),
    Imposter = macula_identity:generate(),
    BadRecord = macula_record:sign(
                  macula_record:station_endpoint(maps:get(station_pk, F), 4433,
                                                 #{host_advertised => [<<"::9">>]}),
                  Imposter),
    Find = stub_find(#{maps:get(storage_key, F) => BadRecord}),
    {error, sig_indeterminate} =
        resolve_mri:resolve(self(), maps:get(mri, F), opts(Find)).

station_envelope_key_mismatch_is_sig_indeterminate(_Config) ->
    F = make_station_fixture(),
    Other   = macula_identity:generate(),
    OtherPk = macula_identity:public(Other),
    OtherRecord = macula_record:sign(
                    macula_record:station_endpoint(OtherPk, 4433,
                                                   #{host_advertised => [<<"::8">>]}),
                    Other),
    OurKey = crypto:hash(sha256,
                         <<"station_endpoint", (maps:get(station_pk, F))/binary>>),
    Find = stub_find(#{OurKey => OtherRecord}),
    {error, sig_indeterminate} =
        resolve_mri:resolve(self(), maps:get(mri, F), opts(Find)).

station_dht_miss_is_not_announced(_Config) ->
    F = make_station_fixture(),
    Find = stub_find(#{}),
    {error, station_not_announced} =
        resolve_mri:resolve(self(), maps:get(mri, F), opts(Find)).

%%====================================================================
%% Non-station MRI types + malformed
%%====================================================================

user_mri_not_resolvable_yet(_Config) ->
    {ok, Mri} = macula_mri:new(user, <<"io.x">>, [<<"acme">>, <<"alice">>]),
    {error, {not_resolvable_yet, user}} =
        resolve_mri:resolve(self(), Mri, #{}).

malformed_mri_rejected(_Config) ->
    {error, malformed_mri} = resolve_mri:resolve(self(), <<"not an mri">>, #{}),
    {error, malformed_station_mri} =
        resolve_mri:resolve(self(), <<"mri:station:NOTVALIDZ32!">>, #{}).

%%====================================================================
%% L5 cache + refresh
%%====================================================================

l5_cache_hit_skips_dht_on_second_resolve(_Config) ->
    F = make_station_fixture(),
    Counter = counters:new(1, []),
    Find = fun(_P, K) ->
        counters:add(Counter, 1, 1),
        case K =:= maps:get(storage_key, F) of
            true  -> {ok, maps:get(record, F)};
            false -> {error, not_found}
        end
    end,
    {ok, [_]} = resolve_mri:resolve(self(), maps:get(mri, F),
                                    #{find_fn => Find, max_attempts => 1}),
    1 = counters:get(Counter, 1),
    {ok, [_]} = resolve_mri:resolve(self(), maps:get(mri, F),
                                    #{find_fn => Find, max_attempts => 1}),
    1 = counters:get(Counter, 1),
    ok.

refresh_invalidates_and_reresolves(_Config) ->
    F = make_station_fixture(),
    Counter = counters:new(1, []),
    Find = fun(_P, K) ->
        counters:add(Counter, 1, 1),
        case K =:= maps:get(storage_key, F) of
            true  -> {ok, maps:get(record, F)};
            false -> {error, not_found}
        end
    end,
    Opts = #{find_fn => Find, max_attempts => 1},
    {ok, [_]} = resolve_mri:resolve(self(), maps:get(mri, F), Opts),
    1 = counters:get(Counter, 1),
    {ok, [_]} = resolve_mri:refresh(self(), maps:get(mri, F), Opts),
    2 = counters:get(Counter, 1),
    ok.

%%====================================================================
%% Proc MRI — full trust-chain resolution
%%====================================================================

proc_mri_resolves_via_trust_chain(_Config) ->
    Foundation = macula_identity:generate(),
    RealmRoot  = macula_identity:generate(),
    Member     = macula_identity:generate(),
    FoundationPk = macula_identity:public(Foundation),
    RealmPk      = macula_identity:public(RealmRoot),
    MemberPk     = macula_identity:public(Member),
    RealmId = <<"io.testrealm">>,
    ok = trust_anchors:put(RealmId, FoundationPk),
    application:set_env(resolve_mesh_names, compiled_in_realm_pubkeys,
                        [{RealmId, RealmPk}]),

    Frtl = macula_record:sign(
             macula_record:foundation_realm_trust_list(FoundationPk, [RealmPk]),
             Foundation),
    Dir  = macula_record:sign(
             macula_record:realm_directory(RealmPk, <<"Test Realm">>, RealmPk),
             RealmRoot),
    Now  = erlang:system_time(millisecond),
    Rme  = macula_record:sign(
             macula_record:realm_member_endorsement(
               RealmPk,
               #{realm => RealmPk, member_node => MemberPk, roles => [<<"user">>]},
               #{valid_from => Now - 1000, valid_until => Now + 86400000}),
             RealmRoot),

    %% macula_mri's segment validator forbids dots inside a segment,
    %% so use slash-separated path segments here. The dotted-form
    %% (`api.users.get') is a presentation concern that the DNS
    %% bridge's qname_proc handles separately; irrelevant for the
    %% trust-chain test.
    {ok, Mri} = macula_mri:new(proc, RealmId,
                               [<<"acme">>, <<"api">>, <<"users">>, <<"get">>]),
    ProcAd = macula_record:sign(
               macula_record:procedure_advertisement(MemberPk, Mri, MemberPk),
               Member),

    Records = #{
        macula_record:storage_key(Frtl)  => Frtl,
        RealmPk                           => Dir,
        macula_record:storage_key(Rme)    => Rme,
        macula_record:storage_key(ProcAd) => ProcAd
    },
    Find = stub_find(Records),
    {ok, [VR]} = resolve_mri:resolve(self(), Mri,
                                     #{find_fn => Find, max_attempts => 1,
                                       retry_delay_ms => 0}),
    #{record_type   := procedure_advertisement,
      mri           := Mri,
      signer_pubkey := MemberPk} = VR,
    ok.
