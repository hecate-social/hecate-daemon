-module(membership_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").

-include("membership_status.hrl").

%% ===================================================================
%% Execute tests
%% ===================================================================

initiate_happy_test() ->
    State = membership_state:new(<<>>),
    Payload = #{
        command_type => initiate_realm_membership,
        membership_id => <<"mem-001">>,
        realm_url => <<"https://macula.io">>,
        initiated_at => 1000
    },
    {ok, [Event]} = membership_aggregate:execute(State, Payload),
    ?assertEqual(<<"realm_membership_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"mem-001">>, maps:get(membership_id, Event)),
    ?assertEqual(<<"https://macula.io">>, maps:get(realm_url, Event)).

initiate_already_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => initiate_realm_membership,
        membership_id => <<"mem-001">>,
        realm_url => <<"https://macula.io">>,
        initiated_at => 2000
    },
    ?assertEqual({error, already_initiated}, membership_aggregate:execute(State, Payload)).

confirm_happy_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => confirm_realm_membership,
        membership_id => <<"mem-001">>,
        realm_id => <<"io.macula">>,
        oauth_account => <<"octocat">>,
        oauth_provider => <<"github">>,
        confirmed_at => 2000
    },
    {ok, [Event]} = membership_aggregate:execute(State, Payload),
    ?assertEqual(<<"realm_membership_confirmed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"octocat">>, maps:get(oauth_account, Event)),
    ?assertEqual(<<"github">>, maps:get(oauth_provider, Event)).

confirm_not_initiated_test() ->
    State = membership_state:new(<<>>),
    Payload = #{
        command_type => confirm_realm_membership,
        membership_id => <<"mem-001">>,
        realm_id => <<"io.macula">>,
        oauth_account => <<"octocat">>,
        oauth_provider => <<"github">>,
        confirmed_at => 2000
    },
    ?assertEqual({error, not_initiated}, membership_aggregate:execute(State, Payload)).

confirm_already_confirmed_test() ->
    State = confirmed_state(),
    Payload = #{
        command_type => confirm_realm_membership,
        membership_id => <<"mem-001">>,
        realm_id => <<"io.macula">>,
        oauth_account => <<"other">>,
        oauth_provider => <<"github">>,
        confirmed_at => 3000
    },
    ?assertEqual({error, already_confirmed}, membership_aggregate:execute(State, Payload)).

%% ===================================================================
%% end_realm_membership (admin revoke path)
%% ===================================================================

end_happy_test() ->
    State = confirmed_state(),
    Payload = #{
        command_type  => end_realm_membership_v1,
        membership_id => <<"mem-001">>,
        reason        => revoked,
        ended_by      => <<"mri:agent:io.macula/admin/host">>,
        ended_at      => 3000
    },
    {ok, [Event]} = membership_aggregate:execute(State, Payload),
    ?assertEqual(<<"realm_membership_ended_v1">>, maps:get(event_type, Event)),
    ?assertEqual(revoked, maps:get(reason, Event)),
    ?assertEqual(<<"mri:agent:io.macula/admin/host">>, maps:get(ended_by, Event)).

end_not_confirmed_test() ->
    State = initiated_state(),
    Payload = #{
        command_type  => end_realm_membership_v1,
        membership_id => <<"mem-001">>,
        reason        => revoked,
        ended_at      => 3000
    },
    ?assertEqual({error, not_confirmed}, membership_aggregate:execute(State, Payload)).

end_already_ended_test() ->
    State = ended_state(revoked),
    Payload = #{
        command_type  => end_realm_membership_v1,
        membership_id => <<"mem-001">>,
        reason        => revoked,
        ended_at      => 4000
    },
    ?assertEqual({error, already_ended}, membership_aggregate:execute(State, Payload)).

%% ===================================================================
%% resign_realm_membership (member authority)
%% ===================================================================

resign_happy_emits_two_events_test() ->
    State = confirmed_state(),
    Payload = #{
        command_type  => resign_realm_membership_v1,
        membership_id => <<"mem-001">>,
        resigned_at   => 5000
    },
    {ok, [ResignedEvt, EndedEvt]} = membership_aggregate:execute(State, Payload),
    ?assertEqual(<<"realm_membership_resigned_v1">>, maps:get(event_type, ResignedEvt)),
    ?assertEqual(<<"realm_membership_ended_v1">>, maps:get(event_type, EndedEvt)),
    %% Both events carry the resigned_at / ended_at timestamp.
    ?assertEqual(5000, maps:get(resigned_at, ResignedEvt)),
    ?assertEqual(5000, maps:get(ended_at, EndedEvt)),
    ?assertEqual(resigned, maps:get(reason, EndedEvt)),
    %% realm_id was enriched from state.
    ?assertEqual(<<"io.macula">>, maps:get(realm_id, ResignedEvt)).

resign_before_confirm_rejected_test() ->
    State = initiated_state(),
    Payload = #{
        command_type  => resign_realm_membership_v1,
        membership_id => <<"mem-001">>,
        resigned_at   => 5000
    },
    ?assertEqual({error, not_confirmed}, membership_aggregate:execute(State, Payload)).

resign_after_end_rejected_test() ->
    State = ended_state(resigned),
    Payload = #{
        command_type  => resign_realm_membership_v1,
        membership_id => <<"mem-001">>,
        resigned_at   => 6000
    },
    ?assertEqual({error, already_ended}, membership_aggregate:execute(State, Payload)).

unknown_command_test() ->
    State = membership_state:new(<<>>),
    ?assertEqual({error, unknown_command},
                 membership_aggregate:execute(State, #{command_type => bogus})).

%% ===================================================================
%% Apply event tests
%% ===================================================================

apply_initiated_test() ->
    State0 = membership_state:new(<<>>),
    Event = #{event_type => <<"realm_membership_initiated_v1">>,
              membership_id => <<"mem-001">>,
              realm_url => <<"https://macula.io">>,
              initiated_at => 1000},
    State1 = membership_aggregate:apply(State0, Event),
    Payload = #{command_type => confirm_realm_membership,
                membership_id => <<"mem-001">>, realm_id => <<"io.macula">>,
                oauth_account => <<"user">>, oauth_provider => <<"github">>,
                confirmed_at => 2000},
    {ok, _} = membership_aggregate:execute(State1, Payload).

apply_confirmed_test() ->
    State0 = initiated_state(),
    Event = #{event_type => <<"realm_membership_confirmed_v1">>,
              membership_id => <<"mem-001">>, realm_id => <<"io.macula">>,
              oauth_account => <<"octocat">>, oauth_provider => <<"github">>,
              confirmed_at => 2000},
    State1 = membership_aggregate:apply(State0, Event),
    Payload = #{command_type => confirm_realm_membership,
                membership_id => <<"mem-001">>, realm_id => <<"io.macula">>,
                oauth_account => <<"x">>, oauth_provider => <<"github">>,
                confirmed_at => 3000},
    ?assertEqual({error, already_confirmed}, membership_aggregate:execute(State1, Payload)).

apply_ended_test() ->
    State0 = confirmed_state(),
    Event = #{event_type => <<"realm_membership_ended_v1">>,
              membership_id => <<"mem-001">>,
              reason => revoked,
              ended_at => 3000},
    State1 = membership_aggregate:apply(State0, Event),
    Payload = #{command_type => end_realm_membership_v1,
                membership_id => <<"mem-001">>,
                reason => revoked, ended_at => 4000},
    ?assertEqual({error, already_ended}, membership_aggregate:execute(State1, Payload)).

%% Historical upcast: old revoked events still fold to ended+revoked.
apply_historical_revoked_upcasts_test() ->
    State0 = confirmed_state(),
    Event = #{event_type => <<"realm_membership_revoked_v1">>,
              membership_id => <<"mem-001">>,
              reason => <<"manual">>, revoked_at => 3000},
    State1 = membership_aggregate:apply(State0, Event),
    Map = membership_state:to_map(State1),
    Status = maps:get(status, Map),
    ?assert(evoq_bit_flags:has(Status, ?MEMBERSHIP_ENDED)),
    ?assert(evoq_bit_flags:has(Status, ?MEMBERSHIP_REVOKED)),
    ?assertEqual(revoked, maps:get(end_reason, Map)),
    ?assertEqual(3000, maps:get(ended_at, Map)).

apply_resigned_test() ->
    State0 = confirmed_state(),
    Event = #{event_type => <<"realm_membership_resigned_v1">>,
              membership_id => <<"mem-001">>,
              resigned_at => 3000},
    State1 = membership_aggregate:apply(State0, Event),
    Map = membership_state:to_map(State1),
    ?assert(evoq_bit_flags:has(maps:get(status, Map), ?MEMBERSHIP_RESIGNED)),
    ?assertEqual(3000, maps:get(resigned_at, Map)).

apply_unknown_event_test() ->
    State0 = membership_state:new(<<>>),
    Event = #{event_type => <<"bogus_v1">>, data => <<"foo">>},
    State1 = membership_aggregate:apply(State0, Event),
    ?assertEqual(State0, State1).

%% ===================================================================
%% Roundtrip tests
%% ===================================================================

roundtrip_full_lifecycle_test() ->
    S0 = membership_state:new(<<>>),
    {ok, [E1]} = membership_aggregate:execute(S0, #{
        command_type => initiate_realm_membership,
        membership_id => <<"mem-001">>,
        realm_url => <<"https://macula.io">>,
        initiated_at => 1000}),
    S1 = membership_aggregate:apply(S0, E1),
    {ok, [E2]} = membership_aggregate:execute(S1, #{
        command_type => confirm_realm_membership,
        membership_id => <<"mem-001">>,
        realm_id => <<"io.macula">>,
        oauth_account => <<"octocat">>,
        oauth_provider => <<"github">>,
        confirmed_at => 2000}),
    S2 = membership_aggregate:apply(S1, E2),
    {ok, [E3]} = membership_aggregate:execute(S2, #{
        command_type  => end_realm_membership_v1,
        membership_id => <<"mem-001">>,
        reason        => revoked,
        ended_at      => 3000}),
    _S3 = membership_aggregate:apply(S2, E3),
    ?assertEqual(<<"realm_membership_initiated_v1">>, maps:get(event_type, E1)),
    ?assertEqual(<<"realm_membership_confirmed_v1">>, maps:get(event_type, E2)),
    ?assertEqual(<<"realm_membership_ended_v1">>, maps:get(event_type, E3)).

%% ===================================================================
%% Helpers
%% ===================================================================

initiated_state() ->
    S0 = membership_state:new(<<>>),
    Event = #{event_type => <<"realm_membership_initiated_v1">>,
              membership_id => <<"mem-001">>,
              realm_url => <<"https://macula.io">>,
              initiated_at => 1000},
    membership_aggregate:apply(S0, Event).

confirmed_state() ->
    S0 = initiated_state(),
    Event = #{event_type => <<"realm_membership_confirmed_v1">>,
              membership_id => <<"mem-001">>,
              realm_id => <<"io.macula">>,
              oauth_account => <<"octocat">>,
              oauth_provider => <<"github">>,
              confirmed_at => 2000},
    membership_aggregate:apply(S0, Event).

ended_state(Reason) ->
    S0 = confirmed_state(),
    Event = #{event_type => <<"realm_membership_ended_v1">>,
              membership_id => <<"mem-001">>,
              reason => Reason,
              ended_at => 3000},
    membership_aggregate:apply(S0, Event).

key_stored_state() ->
    S0 = confirmed_state(),
    Event = #{event_type => <<"realm_shared_key_stored_v1">>,
              membership_id => <<"mem-001">>,
              realm => <<"io.macula">>,
              k_realm_version => 1,
              k_realm_encrypted => <<"sealed-bytes">>,
              received_at => 2500},
    membership_aggregate:apply(S0, Event).

announced_state() ->
    S0 = key_stored_state(),
    Event = #{event_type => <<"identity_public_key_announced_v1">>,
              membership_id => <<"mem-001">>,
              mri => <<"mri:agent:io.macula/alice/host00">>,
              encryption_public_key => <<0:256>>,
              announced_at => 2700},
    membership_aggregate:apply(S0, Event).

%% ===================================================================
%% store_realm_shared_key (Phase C.2)
%% ===================================================================

store_shared_key_happy_test() ->
    State = confirmed_state(),
    Payload = #{
        command_type      => store_realm_shared_key,
        membership_id     => <<"mem-001">>,
        realm             => <<"io.macula">>,
        k_realm_version   => 1,
        k_realm_encrypted => <<"sealed-bytes">>
    },
    {ok, [Event]} = membership_aggregate:execute(State, Payload),
    ?assertEqual(<<"realm_shared_key_stored_v1">>, maps:get(event_type, Event)),
    ?assertEqual(1, maps:get(k_realm_version, Event)),
    ?assertEqual(<<"sealed-bytes">>, maps:get(k_realm_encrypted, Event)),
    S1 = membership_aggregate:apply(State, Event),
    Map = membership_state:to_map(S1),
    Status = maps:get(status, Map),
    ?assert(evoq_bit_flags:has(Status, ?REALM_KEY_STORED)),
    ?assertEqual(1, maps:get(k_realm_version, Map)).

store_shared_key_not_confirmed_test() ->
    State = initiated_state(),
    Payload = #{
        command_type      => store_realm_shared_key,
        membership_id     => <<"mem-001">>,
        realm             => <<"io.macula">>,
        k_realm_version   => 1,
        k_realm_encrypted => <<"sealed">>
    },
    ?assertEqual({error, not_confirmed},
                 membership_aggregate:execute(State, Payload)).

store_shared_key_ended_rejected_test() ->
    State = ended_state(revoked),
    Payload = #{
        command_type      => store_realm_shared_key,
        membership_id     => <<"mem-001">>,
        realm             => <<"io.macula">>,
        k_realm_version   => 1,
        k_realm_encrypted => <<"sealed">>
    },
    ?assertEqual({error, membership_ended},
                 membership_aggregate:execute(State, Payload)).

store_shared_key_rotation_test() ->
    State0 = confirmed_state(),
    {ok, [E1]} = membership_aggregate:execute(State0, #{
        command_type      => store_realm_shared_key,
        membership_id     => <<"mem-001">>,
        realm             => <<"io.macula">>,
        k_realm_version   => 1,
        k_realm_encrypted => <<"v1-bytes">>}),
    State1 = membership_aggregate:apply(State0, E1),
    {ok, [E2]} = membership_aggregate:execute(State1, #{
        command_type      => store_realm_shared_key,
        membership_id     => <<"mem-001">>,
        realm             => <<"io.macula">>,
        k_realm_version   => 2,
        k_realm_encrypted => <<"v2-bytes">>}),
    State2 = membership_aggregate:apply(State1, E2),
    Map = membership_state:to_map(State2),
    ?assertEqual(2, maps:get(k_realm_version, Map)),
    ?assertEqual(<<"v2-bytes">>, maps:get(k_realm_encrypted, Map)),
    ?assert(evoq_bit_flags:has(maps:get(status, Map), ?REALM_KEY_STORED)).

%% ===================================================================
%% announce_identity_public_key (Phase D Session 1)
%% ===================================================================

announce_pubkey_happy_test() ->
    State = key_stored_state(),
    Pub = crypto:strong_rand_bytes(32),
    Payload = #{
        command_type          => announce_identity_public_key,
        membership_id         => <<"mem-001">>,
        mri                   => <<"mri:agent:io.macula/alice/host00">>,
        encryption_public_key => Pub
    },
    {ok, [Event]} = membership_aggregate:execute(State, Payload),
    ?assertEqual(<<"identity_public_key_announced_v1">>,
                 maps:get(event_type, Event)),
    ?assertEqual(Pub, maps:get(encryption_public_key, Event)),
    S1 = membership_aggregate:apply(State, Event),
    Map = membership_state:to_map(S1),
    ?assert(evoq_bit_flags:has(maps:get(status, Map),
                               ?IDENTITY_PUBKEY_ANNOUNCED)),
    ?assert(is_integer(maps:get(identity_pubkey_announced_at, Map))).

announce_pubkey_before_key_stored_rejected_test() ->
    State = confirmed_state(),
    Payload = #{
        command_type          => announce_identity_public_key,
        membership_id         => <<"mem-001">>,
        mri                   => <<"mri:agent:io.macula/alice/host00">>,
        encryption_public_key => crypto:strong_rand_bytes(32)
    },
    ?assertEqual({error, realm_key_not_stored},
                 membership_aggregate:execute(State, Payload)).

announce_pubkey_twice_rejected_test() ->
    State = announced_state(),
    Payload = #{
        command_type          => announce_identity_public_key,
        membership_id         => <<"mem-001">>,
        mri                   => <<"mri:agent:io.macula/alice/host00">>,
        encryption_public_key => crypto:strong_rand_bytes(32)
    },
    ?assertEqual({error, already_announced},
                 membership_aggregate:execute(State, Payload)).

announce_pubkey_after_end_rejected_test() ->
    %% Use an ended state (reason=:revoked) — the end guard blocks announce.
    State0 = announced_state(),
    EndedEvt = #{event_type => <<"realm_membership_ended_v1">>,
                 membership_id => <<"mem-001">>,
                 reason => revoked, ended_at => 9999},
    State = membership_aggregate:apply(State0, EndedEvt),
    Payload = #{
        command_type          => announce_identity_public_key,
        membership_id         => <<"mem-001">>,
        mri                   => <<"mri:agent:io.macula/alice/host00">>,
        encryption_public_key => crypto:strong_rand_bytes(32)
    },
    ?assertEqual({error, membership_ended},
                 membership_aggregate:execute(State, Payload)).

announce_pubkey_missing_fields_rejected_test() ->
    State = key_stored_state(),
    Payload = #{
        command_type => announce_identity_public_key,
        membership_id => <<"mem-001">>
    },
    ?assertEqual({error, missing_fields},
                 membership_aggregate:execute(State, Payload)).
