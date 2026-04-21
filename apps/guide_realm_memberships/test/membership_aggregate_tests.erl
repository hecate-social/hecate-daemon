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

revoke_happy_test() ->
    State = confirmed_state(),
    Payload = #{
        command_type => revoke_realm_membership,
        membership_id => <<"mem-001">>,
        reason => <<"manual">>,
        revoked_at => 3000
    },
    {ok, [Event]} = membership_aggregate:execute(State, Payload),
    ?assertEqual(<<"realm_membership_revoked_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"manual">>, maps:get(reason, Event)).

revoke_not_confirmed_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => revoke_realm_membership,
        membership_id => <<"mem-001">>,
        reason => <<"manual">>,
        revoked_at => 3000
    },
    ?assertEqual({error, not_confirmed}, membership_aggregate:execute(State, Payload)).

revoke_already_revoked_test() ->
    State = revoked_state(),
    Payload = #{
        command_type => revoke_realm_membership,
        membership_id => <<"mem-001">>,
        reason => <<"duplicate">>,
        revoked_at => 4000
    },
    ?assertEqual({error, already_revoked}, membership_aggregate:execute(State, Payload)).

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
    %% Confirm should now work
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
    %% Confirming again should fail
    Payload = #{command_type => confirm_realm_membership,
                membership_id => <<"mem-001">>, realm_id => <<"io.macula">>,
                oauth_account => <<"x">>, oauth_provider => <<"github">>,
                confirmed_at => 3000},
    ?assertEqual({error, already_confirmed}, membership_aggregate:execute(State1, Payload)).

apply_revoked_test() ->
    State0 = confirmed_state(),
    Event = #{event_type => <<"realm_membership_revoked_v1">>,
              membership_id => <<"mem-001">>,
              reason => <<"manual">>, revoked_at => 3000},
    State1 = membership_aggregate:apply(State0, Event),
    %% Revoking again should fail
    Payload = #{command_type => revoke_realm_membership,
                membership_id => <<"mem-001">>,
                reason => <<"again">>, revoked_at => 4000},
    ?assertEqual({error, already_revoked}, membership_aggregate:execute(State1, Payload)).

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
    %% Initiate
    {ok, [E1]} = membership_aggregate:execute(S0, #{
        command_type => initiate_realm_membership,
        membership_id => <<"mem-001">>,
        realm_url => <<"https://macula.io">>,
        initiated_at => 1000}),
    S1 = membership_aggregate:apply(S0, E1),
    %% Confirm
    {ok, [E2]} = membership_aggregate:execute(S1, #{
        command_type => confirm_realm_membership,
        membership_id => <<"mem-001">>,
        realm_id => <<"io.macula">>,
        oauth_account => <<"octocat">>,
        oauth_provider => <<"github">>,
        confirmed_at => 2000}),
    S2 = membership_aggregate:apply(S1, E2),
    %% Revoke
    {ok, [E3]} = membership_aggregate:execute(S2, #{
        command_type => revoke_realm_membership,
        membership_id => <<"mem-001">>,
        reason => <<"manual">>,
        revoked_at => 3000}),
    _S3 = membership_aggregate:apply(S2, E3),
    %% Verify events
    ?assertEqual(<<"realm_membership_initiated_v1">>, maps:get(event_type, E1)),
    ?assertEqual(<<"realm_membership_confirmed_v1">>, maps:get(event_type, E2)),
    ?assertEqual(<<"realm_membership_revoked_v1">>, maps:get(event_type, E3)).

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

revoked_state() ->
    S0 = confirmed_state(),
    Event = #{event_type => <<"realm_membership_revoked_v1">>,
              membership_id => <<"mem-001">>,
              reason => <<"manual">>,
              revoked_at => 3000},
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

store_shared_key_revoked_rejected_test() ->
    State = revoked_state(),
    Payload = #{
        command_type      => store_realm_shared_key,
        membership_id     => <<"mem-001">>,
        realm             => <<"io.macula">>,
        k_realm_version   => 1,
        k_realm_encrypted => <<"sealed">>
    },
    ?assertEqual({error, membership_revoked},
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
