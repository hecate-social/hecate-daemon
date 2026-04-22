-module(hecate_license_guard_tests).
-include_lib("eunit/include/eunit.hrl").

-define(TABLE, realm_shared_keys).
-define(ACCEPTED_TABLE, my_accepted_share_licenses).
-define(SL_ACCEPTED,    2).
-define(SL_CEK_USABLE, 16).
-define(SL_ENDED,       8).

guard_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun fresh_usable_license_passes/1,
      fun stale_catchup_fails/1,
      fun no_catchup_fails/1,
      fun expired_license_fails/1,
      fun unusable_license_fails/1,
      fun custom_threshold_env/1,
      fun stamp_with_no_key_is_noop/1,
      fun last_catchup_reads_stamp/1]}.

setup() ->
    case ets:info(?TABLE) of
        undefined -> ets:new(?TABLE, [public, named_table, set]);
        _         -> ets:delete_all_objects(?TABLE)
    end,
    application:unset_env(hecate, license_staleness_threshold_ms),
    ok.

cleanup(_) ->
    ets:delete_all_objects(?TABLE),
    ok.

fresh_usable_license_passes(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        hecate_license_guard:stamp_catchup(<<"io.macula">>),
        License = license(accepted_usable(), far_future()),
        ?assertEqual(ok, hecate_license_guard:can_open(License, <<"io.macula">>))
    end.

stale_catchup_fails(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        %% stamp a catch-up timestamp from a week ago (>24h threshold)
        WeekAgo = erlang:system_time(millisecond) - 7 * 86400 * 1000,
        hecate_license_guard:stamp_catchup(<<"io.macula">>, WeekAgo),
        License = license(accepted_usable(), far_future()),
        ?assertEqual({error, license_state_stale},
                     hecate_license_guard:can_open(License, <<"io.macula">>))
    end.

no_catchup_fails(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        %% No stamp_catchup called.
        License = license(accepted_usable(), far_future()),
        ?assertEqual({error, license_state_stale},
                     hecate_license_guard:can_open(License, <<"io.macula">>))
    end.

expired_license_fails(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        hecate_license_guard:stamp_catchup(<<"io.macula">>),
        License = license(accepted_usable(), past()),
        ?assertEqual({error, license_expired},
                     hecate_license_guard:can_open(License, <<"io.macula">>))
    end.

unusable_license_fails(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        hecate_license_guard:stamp_catchup(<<"io.macula">>),
        %% ENDED clears CEK_USABLE.
        License = license(?SL_ACCEPTED bor ?SL_ENDED, far_future()),
        ?assertEqual({error, license_not_usable},
                     hecate_license_guard:can_open(License, <<"io.macula">>))
    end.

custom_threshold_env(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        %% Stamp 30s ago.
        At = erlang:system_time(millisecond) - 30000,
        hecate_license_guard:stamp_catchup(<<"io.macula">>, At),
        %% Tighten threshold to 10s — stamp is now stale.
        application:set_env(hecate, license_staleness_threshold_ms, 10000),
        License = license(accepted_usable(), far_future()),
        ?assertEqual({error, license_state_stale},
                     hecate_license_guard:can_open(License, <<"io.macula">>)),
        %% Relax threshold to 60s — stamp is fresh again.
        application:set_env(hecate, license_staleness_threshold_ms, 60000),
        ?assertEqual(ok, hecate_license_guard:can_open(License, <<"io.macula">>)),
        application:unset_env(hecate, license_staleness_threshold_ms)
    end.

stamp_with_no_key_is_noop(_) ->
    fun() ->
        %% Empty table, stamp for a realm without a key — silent no-op.
        hecate_license_guard:stamp_catchup(<<"io.macula">>),
        ?assertEqual(undefined, hecate_license_guard:last_catchup(<<"io.macula">>))
    end.

last_catchup_reads_stamp(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        hecate_license_guard:stamp_catchup(<<"io.macula">>, 123456),
        ?assertEqual(123456, hecate_license_guard:last_catchup(<<"io.macula">>))
    end.

%%====================================================================
%% can_open_file/2
%%====================================================================

can_open_file_test_() ->
    {foreach,
     fun setup_can_open_file/0,
     fun cleanup_can_open_file/1,
     [fun returns_no_license_when_missing/1,
      fun happy_path_with_accepted_license/1,
      fun refuses_ended_license/1,
      fun refuses_realm_mismatch/1,
      fun refuses_when_state_stale/1]}.

setup_can_open_file() ->
    ensure_table(?TABLE),
    ensure_table(?ACCEPTED_TABLE),
    ets:delete_all_objects(?TABLE),
    ets:delete_all_objects(?ACCEPTED_TABLE),
    application:unset_env(hecate, license_staleness_threshold_ms),
    ok.

cleanup_can_open_file(_) ->
    ets:delete_all_objects(?TABLE),
    ets:delete_all_objects(?ACCEPTED_TABLE),
    ok.

ensure_table(Name) ->
    case ets:info(Name) of
        undefined -> ets:new(Name, [public, named_table, set]);
        _         -> ok
    end.

returns_no_license_when_missing(_) ->
    fun() ->
        ?assertEqual({error, no_license},
                     hecate_license_guard:can_open_file(
                         <<"file-unknown">>, <<"io.macula">>))
    end.

happy_path_with_accepted_license(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        hecate_license_guard:stamp_catchup(<<"io.macula">>),
        ets:insert(?ACCEPTED_TABLE,
                   {<<"file-1">>, accepted_entry(<<"file-1">>,
                                                 <<"io.macula">>,
                                                 accepted_usable(),
                                                 far_future())}),
        ?assertEqual(ok, hecate_license_guard:can_open_file(
                             <<"file-1">>, <<"io.macula">>))
    end.

refuses_ended_license(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        hecate_license_guard:stamp_catchup(<<"io.macula">>),
        %% SL_ACCEPTED (2) | SL_ENDED (8) — no CEK_USABLE
        ets:insert(?ACCEPTED_TABLE,
                   {<<"file-2">>, accepted_entry(<<"file-2">>,
                                                 <<"io.macula">>,
                                                 ?SL_ACCEPTED bor ?SL_ENDED,
                                                 far_future())}),
        ?assertEqual({error, license_not_usable},
                     hecate_license_guard:can_open_file(
                         <<"file-2">>, <<"io.macula">>))
    end.

refuses_realm_mismatch(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"other.realm">>, key_entry(<<"other.realm">>)}),
        hecate_license_guard:stamp_catchup(<<"other.realm">>),
        %% License is for other.realm but caller asks about io.macula.
        ets:insert(?ACCEPTED_TABLE,
                   {<<"file-3">>, accepted_entry(<<"file-3">>,
                                                 <<"other.realm">>,
                                                 accepted_usable(),
                                                 far_future())}),
        ?assertEqual({error, license_realm_mismatch},
                     hecate_license_guard:can_open_file(
                         <<"file-3">>, <<"io.macula">>))
    end.

refuses_when_state_stale(_) ->
    fun() ->
        ets:insert(?TABLE, {<<"io.macula">>, key_entry(<<"io.macula">>)}),
        %% Stamp from a week ago.
        WeekAgo = erlang:system_time(millisecond) - 7 * 86400 * 1000,
        hecate_license_guard:stamp_catchup(<<"io.macula">>, WeekAgo),
        ets:insert(?ACCEPTED_TABLE,
                   {<<"file-4">>, accepted_entry(<<"file-4">>,
                                                 <<"io.macula">>,
                                                 accepted_usable(),
                                                 far_future())}),
        ?assertEqual({error, license_state_stale},
                     hecate_license_guard:can_open_file(
                         <<"file-4">>, <<"io.macula">>))
    end.

accepted_entry(FileId, Realm, Status, ExpiresAt) ->
    #{file_id          => FileId,
      license_id       => <<"lic-", FileId/binary>>,
      realm            => Realm,
      status           => Status,
      expires_at       => ExpiresAt,
      k_realm_version  => 1,
      wrap_strategy    => realm_key_v1,
      wrapped_cek      => <<"wrapped">>,
      accepted_cek_sealed => <<"sealed">>}.

%% --- helpers ---

accepted_usable() -> ?SL_ACCEPTED bor ?SL_CEK_USABLE.

far_future() -> erlang:system_time(millisecond) + 86400000.
past() -> erlang:system_time(millisecond) - 1.

license(Status, ExpiresAt) ->
    #{status => Status, expires_at => ExpiresAt}.

key_entry(Realm) ->
    #{realm             => Realm,
      k_realm_version   => 1,
      k_realm_encrypted => <<"sealed">>,
      received_at       => 1}.
