-module(share_license_lifecycle_to_accepted_index_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_share_license_lifecycle/include/share_license_status.hrl").

-define(TABLE, my_accepted_share_licenses).

projection_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun inserts_on_accept/1,
      fun clears_cek_usable_on_end/1,
      fun updates_on_rewrap_received/1,
      fun missing_license_id_on_end_no_op/1,
      fun missing_file_id_ignored/1]}.

setup() ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _         -> ets:delete(?TABLE)
    end,
    {ok, State, RM} = share_license_lifecycle_to_accepted_index:init(#{}),
    {State, RM}.

cleanup(_) ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _         -> ets:delete(?TABLE)
    end,
    ok.

inserts_on_accept({S, RM}) ->
    fun() ->
        {ok, _S2, _RM2} = share_license_lifecycle_to_accepted_index:project(
                             accepted_event(<<"file-1">>, <<"lic-1">>),
                             #{}, S, RM),
        {ok, Entry} = project_share_licenses_store:get_accepted_by_file_id(
                         <<"file-1">>),
        ?assertEqual(<<"lic-1">>, maps:get(license_id, Entry)),
        Status = maps:get(status, Entry),
        ?assert(evoq_bit_flags:has(Status, ?SL_ACCEPTED)),
        ?assert(evoq_bit_flags:has(Status, ?SL_CEK_USABLE))
    end.

clears_cek_usable_on_end({S, RM}) ->
    fun() ->
        {ok, S1, RM1} = share_license_lifecycle_to_accepted_index:project(
                             accepted_event(<<"file-2">>, <<"lic-2">>),
                             #{}, S, RM),
        {ok, _S2, _RM2} = share_license_lifecycle_to_accepted_index:project(
                             ended_event(<<"lic-2">>, revoked),
                             #{}, S1, RM1),
        {ok, Entry} = project_share_licenses_store:get_accepted_by_file_id(
                         <<"file-2">>),
        Status = maps:get(status, Entry),
        ?assertNot(evoq_bit_flags:has(Status, ?SL_CEK_USABLE)),
        ?assert(evoq_bit_flags:has(Status, ?SL_ENDED)),
        ?assertEqual(revoked, maps:get(end_reason, Entry))
    end.

updates_on_rewrap_received({S, RM}) ->
    fun() ->
        {ok, S1, RM1} = share_license_lifecycle_to_accepted_index:project(
                             accepted_event(<<"file-3">>, <<"lic-3">>),
                             #{}, S, RM),
        {ok, _S2, _RM2} = share_license_lifecycle_to_accepted_index:project(
                             rewrap_event(<<"lic-3">>, 2, <<"new-wrap">>),
                             #{}, S1, RM1),
        {ok, Entry} = project_share_licenses_store:get_accepted_by_file_id(
                         <<"file-3">>),
        ?assertEqual(<<"new-wrap">>, maps:get(wrapped_cek, Entry)),
        ?assertEqual(2, maps:get(k_realm_version, Entry)),
        %% accepted_cek_sealed untouched
        ?assertEqual(<<"sealed">>, maps:get(accepted_cek_sealed, Entry)),
        ?assert(evoq_bit_flags:has(maps:get(status, Entry), ?SL_REWRAPPED)),
        %% CEK_USABLE still set after rewrap
        ?assert(evoq_bit_flags:has(maps:get(status, Entry), ?SL_CEK_USABLE))
    end.

missing_license_id_on_end_no_op({S, RM}) ->
    fun() ->
        %% An end event referring to a license we never accepted is
        %% silently ignored — not an error.
        {ok, _S2, _RM2} = share_license_lifecycle_to_accepted_index:project(
                             ended_event(<<"lic-unknown">>, revoked),
                             #{}, S, RM),
        ?assertEqual({error, not_found},
                     project_share_licenses_store:get_accepted_by_file_id(
                         <<"file-unknown">>))
    end.

missing_file_id_ignored({S, RM}) ->
    fun() ->
        Evt = #{event_type => <<"license_accepted_v1">>,
                data => #{license_id => <<"lic-x">>}},
        {ok, _S2, _RM2} = share_license_lifecycle_to_accepted_index:project(
                             Evt, #{}, S, RM),
        {ok, All} = project_share_licenses_store:list_accepted(),
        ?assertEqual([], All)
    end.

%% --- helpers ---

accepted_event(FileId, LicenseId) ->
    #{event_type => <<"license_accepted_v1">>,
      data => #{
        license_id          => LicenseId,
        file_id             => FileId,
        grantee             => <<"mri:agent:io.macula/bob/host00">>,
        wrap_strategy       => did_x25519_v1,
        wrapped_cek         => <<"wrapped">>,
        accepted_cek_sealed => <<"sealed">>,
        k_realm_version     => 1,
        issuer_did          => <<"mri:agent:io.macula/alice/host00">>,
        realm               => <<"io.macula">>,
        issued_at           => 1000,
        accepted_at         => 1500,
        expires_at          => 99999999}}.

ended_event(LicenseId, Reason) ->
    #{event_type => <<"license_ended_v1">>,
      data => #{license_id => LicenseId,
                reason     => Reason,
                ended_at   => 9000}}.

rewrap_event(LicenseId, NewVersion, NewWrappedCek) ->
    #{event_type => <<"license_rewrap_received_v1">>,
      data => #{license_id          => LicenseId,
                new_wrapped_cek     => NewWrappedCek,
                new_k_realm_version => NewVersion,
                batch_id            => <<"rotation-batch">>,
                rewrapped_at        => 9500}}.
