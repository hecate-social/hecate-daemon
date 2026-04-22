-module(share_license_lifecycle_to_issued_index_tests).
-include_lib("eunit/include/eunit.hrl").

-define(TABLE, my_issued_realm_scoped_active_licenses).

projection_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun inserts_realm_scope_issue/1,
      fun ignores_did_scope_issue/1,
      fun deletes_on_revoke/1,
      fun updates_on_rewrap/1,
      fun list_for_realm_version/1]}.

setup() ->
    %% The projection uses evoq_read_model_ets which creates the table
    %% if it doesn't exist. Init the model once per test.
    case ets:info(?TABLE) of
        undefined -> ok;
        _         -> ets:delete(?TABLE)
    end,
    {ok, State, RM} = share_license_lifecycle_to_issued_index:init(#{}),
    {State, RM}.

cleanup(_) ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _         -> ets:delete(?TABLE)
    end,
    ok.

inserts_realm_scope_issue({S, RM}) ->
    fun() ->
        Evt = issued_event(<<"lic-1">>, realm_key_v1, 1),
        {ok, _S2, RM2} = share_license_lifecycle_to_issued_index:project(
                            Evt, #{}, S, RM),
        ?assertMatch({ok, #{license_id := <<"lic-1">>,
                            k_realm_version := 1,
                            wrap_strategy := realm_key_v1}},
                     project_share_licenses_store:get(<<"lic-1">>)),
        _ = RM2
    end.

ignores_did_scope_issue({S, RM}) ->
    fun() ->
        Evt = issued_event(<<"lic-2">>, did_x25519_v1, 1),
        {ok, _S2, _RM2} = share_license_lifecycle_to_issued_index:project(
                            Evt, #{}, S, RM),
        ?assertEqual({error, not_found},
                     project_share_licenses_store:get(<<"lic-2">>))
    end.

deletes_on_revoke({S, RM}) ->
    fun() ->
        {ok, S1, RM1} = share_license_lifecycle_to_issued_index:project(
                            issued_event(<<"lic-3">>, realm_key_v1, 1),
                            #{}, S, RM),
        {ok, _S2, _RM2} = share_license_lifecycle_to_issued_index:project(
                            revoked_event(<<"lic-3">>), #{}, S1, RM1),
        ?assertEqual({error, not_found},
                     project_share_licenses_store:get(<<"lic-3">>))
    end.

updates_on_rewrap({S, RM}) ->
    fun() ->
        {ok, S1, RM1} = share_license_lifecycle_to_issued_index:project(
                            issued_event(<<"lic-4">>, realm_key_v1, 1),
                            #{}, S, RM),
        {ok, _S2, _RM2} = share_license_lifecycle_to_issued_index:project(
                            rewrapped_event(<<"lic-4">>, 2), #{}, S1, RM1),
        {ok, Entry} = project_share_licenses_store:get(<<"lic-4">>),
        ?assertEqual(2, maps:get(k_realm_version, Entry)),
        ?assertEqual(<<"fresh-wrap">>, maps:get(wrapped_cek, Entry))
    end.

list_for_realm_version({S, RM}) ->
    fun() ->
        {ok, S1, RM1} = share_license_lifecycle_to_issued_index:project(
                            issued_event(<<"lic-a">>, realm_key_v1, 2),
                            #{}, S, RM),
        {ok, S2, RM2} = share_license_lifecycle_to_issued_index:project(
                            issued_event(<<"lic-b">>, realm_key_v1, 2),
                            #{}, S1, RM1),
        {ok, _S3, _RM3} = share_license_lifecycle_to_issued_index:project(
                            issued_event_at(<<"lic-c">>, realm_key_v1, 3,
                                             <<"other.realm">>),
                            #{}, S2, RM2),
        {ok, Entries} = project_share_licenses_store:list_active_for_realm_version(
                            <<"io.macula">>, 2),
        Ids = lists:sort([maps:get(license_id, E) || E <- Entries]),
        ?assertEqual([<<"lic-a">>, <<"lic-b">>], Ids)
    end.

%% --- helpers ---

issued_event(LicenseId, WrapStrategy, Version) ->
    issued_event_at(LicenseId, WrapStrategy, Version, <<"io.macula">>).

issued_event_at(LicenseId, WrapStrategy, Version, Realm) ->
    #{event_type        => <<"license_issued_v1">>,
      data => #{
        license_id        => LicenseId,
        file_id           => <<"file-1">>,
        grantee           => <<"mri:realm:io.macula">>,
        wrap_strategy     => WrapStrategy,
        wrapped_cek       => <<"wrap">>,
        origin_cek_sealed => <<"sealed-cek">>,
        k_realm_version   => Version,
        issuer_did        => <<"mri:agent:io.macula/alice/host00">>,
        realm             => Realm,
        batch_id          => <<"batch-1">>,
        issued_at         => 1000,
        expires_at        => 99999}}.

revoked_event(LicenseId) ->
    #{event_type => <<"share_license_revoked_v1">>,
      data => #{
        license_id => LicenseId,
        reason     => revoked,
        revoked_at => 5000}}.

rewrapped_event(LicenseId, NewVersion) ->
    #{event_type => <<"license_rewrapped_v1">>,
      data => #{
        license_id          => LicenseId,
        new_wrapped_cek     => <<"fresh-wrap">>,
        new_k_realm_version => NewVersion,
        batch_id            => <<"rot-batch-1">>,
        rewrapped_at        => 9000}}.
