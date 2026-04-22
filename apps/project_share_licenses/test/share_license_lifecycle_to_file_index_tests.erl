-module(share_license_lifecycle_to_file_index_tests).
-include_lib("eunit/include/eunit.hrl").

-define(TABLE, my_issued_files).

projection_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun inserts_on_first_issue/1,
      fun idempotent_on_replay/1,
      fun ignores_missing_file_id/1,
      fun ignores_missing_sealed/1]}.

setup() ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _         -> ets:delete(?TABLE)
    end,
    {ok, State, RM} = share_license_lifecycle_to_file_index:init(#{}),
    {State, RM}.

cleanup(_) ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _         -> ets:delete(?TABLE)
    end,
    ok.

inserts_on_first_issue({S, RM}) ->
    fun() ->
        {ok, _S2, _RM2} = share_license_lifecycle_to_file_index:project(
                             issued_event(<<"file-1">>, <<"sealed-a">>),
                             #{}, S, RM),
        {ok, Entry} = project_share_licenses_store:get_issued_file(<<"file-1">>),
        ?assertEqual(<<"sealed-a">>, maps:get(origin_cek_sealed, Entry)),
        ?assertEqual(<<"io.macula">>, maps:get(realm, Entry))
    end.

idempotent_on_replay({S, RM}) ->
    fun() ->
        {ok, S1, RM1} = share_license_lifecycle_to_file_index:project(
                             issued_event(<<"file-2">>, <<"sealed-b">>),
                             #{}, S, RM),
        %% Same event replayed — should stay one entry, same bytes.
        {ok, _S2, _RM2} = share_license_lifecycle_to_file_index:project(
                             issued_event(<<"file-2">>, <<"sealed-b">>),
                             #{}, S1, RM1),
        {ok, Entry} = project_share_licenses_store:get_issued_file(<<"file-2">>),
        ?assertEqual(<<"sealed-b">>, maps:get(origin_cek_sealed, Entry))
    end.

ignores_missing_file_id({S, RM}) ->
    fun() ->
        Evt = #{event_type => <<"license_issued_v1">>,
                data => #{origin_cek_sealed => <<"sealed">>,
                          realm => <<"io.macula">>}},
        {ok, _S2, _RM2} = share_license_lifecycle_to_file_index:project(
                             Evt, #{}, S, RM),
        {ok, All} = project_share_licenses_store:list_accepted(),
        ?assertEqual([], All)
    end.

ignores_missing_sealed({S, RM}) ->
    fun() ->
        Evt = #{event_type => <<"license_issued_v1">>,
                data => #{file_id => <<"file-x">>,
                          realm => <<"io.macula">>}},
        {ok, _S2, _RM2} = share_license_lifecycle_to_file_index:project(
                             Evt, #{}, S, RM),
        ?assertEqual({error, not_found},
                     project_share_licenses_store:get_issued_file(<<"file-x">>))
    end.

%% --- helpers ---

issued_event(FileId, Sealed) ->
    #{event_type => <<"license_issued_v1">>,
      data => #{
        license_id        => <<"lic-", FileId/binary>>,
        file_id           => FileId,
        grantee           => <<"mri:realm:io.macula">>,
        wrap_strategy     => realm_key_v1,
        wrapped_cek       => <<"wrap">>,
        origin_cek_sealed => Sealed,
        k_realm_version   => 1,
        issuer_did        => <<"mri:agent:io.macula/alice/host00">>,
        realm             => <<"io.macula">>,
        batch_id          => <<"batch-1">>,
        issued_at         => 1000,
        expires_at        => 99999}}.
