-module(issued_license_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").
-include("share_license_status.hrl").

%% --- execute ---

issue_happy_test() ->
    State = issued_license_state:new(<<"issued-license-lic-1">>),
    Payload = issue_payload(<<"lic-1">>),
    {ok, [Event]} = issued_license_aggregate:execute(State, Payload),
    ?assertEqual(<<"license_issued_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lic-1">>, maps:get(license_id, Event)),
    ?assertEqual(realm_key_v1, maps:get(wrap_strategy, Event)),
    %% default expires_at = issued_at + 10y when omitted
    IssuedAt = maps:get(issued_at, Event),
    ExpiresAt = maps:get(expires_at, Event),
    ?assert(ExpiresAt > IssuedAt).

issue_missing_field_test() ->
    State = issued_license_state:new(<<>>),
    Payload = maps:remove(file_id, issue_payload(<<"lic-1">>)),
    ?assertEqual({error, {missing, file_id}},
                 issued_license_aggregate:execute(State, Payload)).

issue_after_issued_rejected_test() ->
    State = issued_state(<<"lic-1">>),
    Payload = issue_payload(<<"lic-1">>),
    ?assertEqual({error, already_issued},
                 issued_license_aggregate:execute(State, Payload)).

unknown_on_empty_test() ->
    State = issued_license_state:new(<<>>),
    ?assertEqual({error, license_not_issued},
                 issued_license_aggregate:execute(State, #{command_type => bogus})).

unknown_on_issued_test() ->
    State = issued_state(<<"lic-1">>),
    ?assertEqual({error, unknown_command},
                 issued_license_aggregate:execute(State, #{command_type => bogus})).

revoke_happy_test() ->
    State = issued_state(<<"lic-1">>),
    Payload = #{command_type => revoke_share_license_v1,
                license_id   => <<"lic-1">>,
                reason       => kicked,
                revoked_at   => 5000},
    {ok, [Event]} = issued_license_aggregate:execute(State, Payload),
    ?assertEqual(<<"share_license_revoked_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lic-1">>, maps:get(license_id, Event)),
    %% enrich_from_state pulled grantee/realm/issuer_did off state:
    ?assertEqual(<<"mri:realm:io.macula">>, maps:get(grantee, Event)),
    ?assertEqual(<<"io.macula">>, maps:get(realm, Event)),
    ?assertEqual(<<"mri:agent:io.macula/alice/host00">>, maps:get(issuer_did, Event)),
    ?assertEqual(kicked, maps:get(reason, Event)),
    ?assertEqual(5000, maps:get(revoked_at, Event)).

revoke_before_issue_rejected_test() ->
    State = issued_license_state:new(<<>>),
    Payload = #{command_type => revoke_share_license_v1,
                license_id   => <<"lic-1">>,
                reason       => kicked},
    ?assertEqual({error, license_not_issued},
                 issued_license_aggregate:execute(State, Payload)).

revoke_after_revoke_rejected_test() ->
    State0 = issued_state(<<"lic-1">>),
    RevEvt = #{event_type => <<"share_license_revoked_v1">>,
               license_id => <<"lic-1">>,
               reason     => kicked,
               revoked_at => 5000},
    State1 = issued_license_aggregate:apply(State0, RevEvt),
    Payload = #{command_type => revoke_share_license_v1,
                license_id   => <<"lic-1">>,
                reason       => double_kicked},
    ?assertEqual({error, license_revoked},
                 issued_license_aggregate:execute(State1, Payload)).

%% --- rewrap command ---

rewrap_happy_test() ->
    State = issued_state(<<"lic-1">>),
    Payload = rewrap_payload(<<"lic-1">>, 2),
    {ok, [Event]} = issued_license_aggregate:execute(State, Payload),
    ?assertEqual(<<"license_rewrapped_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lic-1">>, maps:get(license_id, Event)),
    ?assertEqual(<<"new-wrapped">>, maps:get(new_wrapped_cek, Event)),
    ?assertEqual(2, maps:get(new_k_realm_version, Event)),
    %% enrich_from_state pulled realm/grantee/issuer_did off state:
    ?assertEqual(<<"mri:realm:io.macula">>, maps:get(grantee, Event)),
    ?assertEqual(<<"io.macula">>, maps:get(realm, Event)),
    ?assertEqual(<<"mri:agent:io.macula/alice/host00">>, maps:get(issuer_did, Event)).

rewrap_stale_version_rejected_test() ->
    %% issued_state/1 starts at k_realm_version = 1. A rewrap to v1 must
    %% fail (not strictly greater) — this is the monotonic guard.
    State = issued_state(<<"lic-1">>),
    Payload = rewrap_payload(<<"lic-1">>, 1),
    ?assertEqual({error, stale_rewrap},
                 issued_license_aggregate:execute(State, Payload)).

rewrap_old_version_rejected_test() ->
    %% After a rewrap to v2 lands, a replayed v2 (same version) must
    %% be rejected — replay produces no corrupt state.
    State0 = issued_state(<<"lic-1">>),
    State1 = issued_license_aggregate:apply(State0, rewrap_event(<<"lic-1">>, 2)),
    Payload = rewrap_payload(<<"lic-1">>, 2),
    ?assertEqual({error, stale_rewrap},
                 issued_license_aggregate:execute(State1, Payload)).

rewrap_before_issue_rejected_test() ->
    State = issued_license_state:new(<<>>),
    Payload = rewrap_payload(<<"lic-1">>, 2),
    ?assertEqual({error, license_not_issued},
                 issued_license_aggregate:execute(State, Payload)).

rewrap_after_revoke_rejected_test() ->
    State0 = issued_state(<<"lic-r">>),
    State1 = issued_license_aggregate:apply(State0,
                #{event_type => <<"share_license_revoked_v1">>,
                  license_id => <<"lic-r">>,
                  reason     => kicked,
                  revoked_at => 5000}),
    Payload = rewrap_payload(<<"lic-r">>, 2),
    ?assertEqual({error, license_revoked},
                 issued_license_aggregate:execute(State1, Payload)).

%% --- apply ---

apply_issued_sets_issued_bit_test() ->
    State0 = issued_license_state:new(<<>>),
    State1 = issued_license_aggregate:apply(State0, issued_event(<<"lic-x">>)),
    Map = issued_license_state:to_map(State1),
    ?assert(evoq_bit_flags:has(maps:get(status, Map), ?SL_ISSUED)),
    ?assertEqual(<<"lic-x">>, maps:get(license_id, Map)).

apply_revoked_sets_revoked_bit_test() ->
    State0 = issued_state(<<"lic-r">>),
    RevEvt = #{event_type => <<"share_license_revoked_v1">>,
               license_id => <<"lic-r">>,
               reason     => <<"kicked">>,
               revoked_at => 9999},
    State1 = issued_license_aggregate:apply(State0, RevEvt),
    Status = maps:get(status, issued_license_state:to_map(State1)),
    ?assert(evoq_bit_flags:has(Status, ?SL_REVOKED)),
    ?assert(evoq_bit_flags:has(Status, ?SL_ISSUED)).

apply_rewrapped_sets_rewrapped_bit_test() ->
    State0 = issued_state(<<"lic-w">>),
    RwEvt = #{event_type        => <<"license_rewrapped_v1">>,
              license_id        => <<"lic-w">>,
              new_wrapped_cek   => <<"new-wrapped">>,
              new_k_realm_version => 2,
              rewrapped_at      => 1234},
    State1 = issued_license_aggregate:apply(State0, RwEvt),
    Map = issued_license_state:to_map(State1),
    Status = maps:get(status, Map),
    ?assert(evoq_bit_flags:has(Status, ?SL_REWRAPPED)),
    ?assertEqual(<<"new-wrapped">>, maps:get(wrapped_cek, Map)),
    ?assertEqual(2, maps:get(k_realm_version, Map)).

stream_id_test() ->
    ?assertEqual(<<"issued-license-abc">>,
                 issued_license_aggregate:stream_id(<<"abc">>)).

%% --- helpers ---

issue_payload(LicenseId) ->
    #{command_type      => issue_license_v1,
      license_id        => LicenseId,
      file_id           => <<"file-1">>,
      grantee           => <<"mri:realm:io.macula">>,
      wrap_strategy     => realm_key_v1,
      wrapped_cek       => <<"wrapped-bytes">>,
      origin_cek_sealed => <<"sealed-bytes">>,
      k_realm_version   => 1,
      issuer_did        => <<"mri:agent:io.macula/alice/host00">>,
      realm             => <<"io.macula">>,
      batch_id          => <<"batch-abc">>,
      issued_at         => 1000}.

issued_event(LicenseId) ->
    #{event_type        => <<"license_issued_v1">>,
      license_id        => LicenseId,
      file_id           => <<"file-1">>,
      grantee           => <<"mri:realm:io.macula">>,
      wrap_strategy     => realm_key_v1,
      wrapped_cek       => <<"wrapped-bytes">>,
      origin_cek_sealed => <<"sealed-bytes">>,
      k_realm_version   => 1,
      issuer_did        => <<"mri:agent:io.macula/alice/host00">>,
      realm             => <<"io.macula">>,
      batch_id          => <<"batch-abc">>,
      issued_at         => 1000,
      expires_at        => 1000 + 10*365*24*3600*1000}.

issued_state(LicenseId) ->
    S0 = issued_license_state:new(<<>>),
    issued_license_aggregate:apply(S0, issued_event(LicenseId)).

rewrap_payload(LicenseId, Version) ->
    #{command_type        => rewrap_license_v1,
      license_id          => LicenseId,
      new_wrapped_cek     => <<"new-wrapped">>,
      new_k_realm_version => Version,
      batch_id            => <<"rotation-batch-1">>,
      rewrapped_at        => 9000}.

rewrap_event(LicenseId, Version) ->
    #{event_type          => <<"license_rewrapped_v1">>,
      license_id          => LicenseId,
      new_wrapped_cek     => <<"new-wrapped">>,
      new_k_realm_version => Version,
      batch_id            => <<"rotation-batch-1">>,
      rewrapped_at        => 9000}.
