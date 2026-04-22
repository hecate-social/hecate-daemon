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

%% --- apply ---

apply_issued_sets_issued_bit_test() ->
    State0 = issued_license_state:new(<<>>),
    State1 = issued_license_aggregate:apply(State0, issued_event(<<"lic-x">>)),
    Map = issued_license_state:to_map(State1),
    ?assert(evoq_bit_flags:has(maps:get(status, Map), ?SL_ISSUED)),
    ?assertEqual(<<"lic-x">>, maps:get(license_id, Map)).

apply_revoked_sets_revoked_bit_test() ->
    State0 = issued_state(<<"lic-r">>),
    RevEvt = #{event_type => <<"license_revoked_v1">>,
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
