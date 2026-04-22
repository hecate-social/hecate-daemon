-module(accepted_license_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").
-include("share_license_status.hrl").

%% --- apply_event ---

apply_accepted_sets_accepted_and_cek_usable_test() ->
    State0 = accepted_license_state:new(<<>>),
    State1 = accepted_license_aggregate:apply(State0, accepted_event(<<"lic-a">>)),
    Map = accepted_license_state:to_map(State1),
    Status = maps:get(status, Map),
    ?assert(evoq_bit_flags:has(Status, ?SL_ACCEPTED)),
    ?assert(evoq_bit_flags:has(Status, ?SL_CEK_USABLE)),
    ?assertEqual(<<"lic-a">>, maps:get(license_id, Map)),
    ?assertEqual(<<"sealed-accepted">>, maps:get(accepted_cek_sealed, Map)).

apply_ended_clears_cek_usable_test() ->
    State0 = accepted_state(<<"lic-e">>),
    EndEvt = #{event_type => <<"license_ended_v1">>,
               license_id => <<"lic-e">>,
               reason     => revoked,
               ended_at   => 9999},
    State1 = accepted_license_aggregate:apply(State0, EndEvt),
    Status = maps:get(status, accepted_license_state:to_map(State1)),
    ?assert(evoq_bit_flags:has(Status, ?SL_ENDED)),
    ?assertNot(evoq_bit_flags:has(Status, ?SL_CEK_USABLE)),
    ?assert(evoq_bit_flags:has(Status, ?SL_ACCEPTED)).

apply_rewrap_updates_wrapped_cek_test() ->
    State0 = accepted_state(<<"lic-r">>),
    RwEvt = #{event_type          => <<"license_rewrap_received_v1">>,
              license_id          => <<"lic-r">>,
              new_wrapped_cek     => <<"fresh-wrap">>,
              new_k_realm_version => 2},
    State1 = accepted_license_aggregate:apply(State0, RwEvt),
    Map = accepted_license_state:to_map(State1),
    ?assertEqual(<<"fresh-wrap">>, maps:get(wrapped_cek, Map)),
    ?assertEqual(2, maps:get(k_realm_version, Map)),
    %% plaintext CEK seal untouched on rewrap
    ?assertEqual(<<"sealed-accepted">>, maps:get(accepted_cek_sealed, Map)),
    ?assert(evoq_bit_flags:has(maps:get(status, Map), ?SL_REWRAPPED)).

%% --- execute (state-only, no crypto) ---

end_after_accepted_happy_test() ->
    State = accepted_state(<<"lic-e">>),
    Payload = #{command_type => end_license_v1,
                license_id   => <<"lic-e">>,
                reason       => revoked,
                ended_at     => 1},
    {ok, [Event]} = accepted_license_aggregate:execute(State, Payload),
    ?assertEqual(<<"license_ended_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lic-e">>, maps:get(license_id, Event)).

end_twice_rejected_test() ->
    State0 = accepted_state(<<"lic-e2">>),
    EndEvt = #{event_type => <<"license_ended_v1">>,
               license_id => <<"lic-e2">>,
               reason     => revoked,
               ended_at   => 1},
    State1 = accepted_license_aggregate:apply(State0, EndEvt),
    Payload = #{command_type => end_license_v1,
                license_id   => <<"lic-e2">>,
                reason       => revoked},
    ?assertEqual({error, license_ended},
                 accepted_license_aggregate:execute(State1, Payload)).

accept_twice_rejected_test() ->
    State = accepted_state(<<"lic-dup">>),
    Payload = #{command_type => accept_license_v1,
                license_id   => <<"lic-dup">>},
    ?assertEqual({error, already_accepted},
                 accepted_license_aggregate:execute(State, Payload)).

end_before_accept_rejected_test() ->
    State = accepted_license_state:new(<<>>),
    Payload = #{command_type => end_license_v1,
                license_id   => <<"lic-e">>,
                reason       => revoked},
    ?assertEqual({error, license_not_accepted},
                 accepted_license_aggregate:execute(State, Payload)).

stream_id_test() ->
    ?assertEqual(<<"accepted-license-xyz">>,
                 accepted_license_aggregate:stream_id(<<"xyz">>)).

%% --- helpers ---

accepted_event(LicenseId) ->
    #{event_type          => <<"license_accepted_v1">>,
      license_id          => LicenseId,
      file_id             => <<"file-1">>,
      grantee             => <<"mri:agent:io.macula/bob/host00">>,
      wrap_strategy       => did_x25519_v1,
      wrapped_cek         => <<"wrapped">>,
      accepted_cek_sealed => <<"sealed-accepted">>,
      k_realm_version     => undefined,
      issuer_did          => <<"mri:agent:io.macula/alice/host00">>,
      realm               => <<"io.macula">>,
      issued_at           => 1000,
      accepted_at         => 1500,
      expires_at          => 99999}.

accepted_state(LicenseId) ->
    S0 = accepted_license_state:new(<<>>),
    accepted_license_aggregate:apply(S0, accepted_event(LicenseId)).
