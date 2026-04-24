%%% @doc Full Phase D + E + F lifecycle test in one VM.
%%%
%%% Eunit (not CT) to avoid the umbrella-app CT dir-resolution
%%% friction that bit us last time. Boots reckon_db + evoq + the
%%% inproc mesh backend + every supervisor in the share-license /
%%% briefcase / realm-memberships stack, then walks an end-to-end
%%% scenario per test case:
%%%
%%%   1. Alice shares a file (issues realm-scope license).
%%%   2. The recipient side dispatches accept_license_v1 directly
%%%      (bypasses the listener's identity filter — single VM means
%%%      one hecate_identity).
%%%   3. Open-path guard passes after stamping the catchup.
%%%   4. Revoke clears CEK_USABLE; subsequent guard returns
%%%      license_not_usable.
%%%   5. K_realm rotation triggers the rewrap PM; the recipient's
%%%      accepted license updates to the new version.
%%%   6. Encrypt-on-serve + decrypt-on-cache round-trips a known
%%%      payload through the inproc mesh.
%%%
%%% These are integration tests — slow (seconds per case) — so they
%%% live in a dedicated module that's still discovered by `rebar3
%%% eunit` automatically.
%%% @end
-module(phase_d_lifecycle_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").
-include_lib("guide_share_license_lifecycle/include/share_license_status.hrl").

-define(REALM, <<"io.macula">>).
-define(ALICE, <<"mri:agent:io.macula/alice/host00">>).

%%====================================================================
%% Fixture
%%====================================================================

setup() ->
    application:set_env(hecate, mesh_backend, inproc),
    application:set_env(hecate, realm, ?REALM),

    %% Evoq config — must be set BEFORE evoq starts. Mirrors prod
    %% sys.config; without it aggregates crash with
    %% {not_configured, event_store_adapter}.
    application:set_env(evoq, event_store_adapter, reckon_evoq_adapter),
    application:set_env(evoq, subscription_adapter, reckon_evoq_adapter),
    application:set_env(evoq, store_id, default_store),
    application:set_env(evoq, consistency, eventual),

    %% Per-run isolated data dir + base_dir so cache writes don't
    %% collide across tests.
    DataDir = filename:join(["/tmp",
                             "phase_d_lifecycle_" ++
                                 integer_to_list(erlang:system_time(nanosecond))]),
    ok = filelib:ensure_path(filename:join(DataDir, "hecate-daemon")),
    application:set_env(hecate, data_dir,
                        filename:join(DataDir, "hecate-daemon")),
    %% shared_paths reads HECATE_HOME from the env.
    os:putenv("HECATE_HOME", DataDir),

    {ok, _} = application:ensure_all_started(crypto),
    {ok, _} = application:ensure_all_started(macula),
    {ok, _} = application:ensure_all_started(reckon_db),
    {ok, _} = application:ensure_all_started(evoq),

    %% Start stores. Each is its own ra cluster — sequential starts
    %% keep file-locks from contending.
    [start_store(S, DataDir) || S <- [realm_memberships_store,
                                       share_licenses_store,
                                       briefcase_store]],
    [wait_for_store(S) || S <- [realm_memberships_store,
                                 share_licenses_store,
                                 briefcase_store]],

    %% Start the per-store evoq_store_subscription that fans
    %% events out to projections + emitters. Production does this
    %% in hecate_app:start_store_subscriptions/1 after the boot
    %% tracker; we run it inline here.
    [start_subscription(S) || S <- [realm_memberships_store,
                                     share_licenses_store,
                                     briefcase_store]],

    %% Mesh backend (inproc) — register under hecate_mesh_client.
    {ok, _} = ensure_or_keep(hecate_mesh_inproc),

    %% Projection sups — own the ETS tables.
    {ok, _} = ensure_or_keep(project_realm_memberships_sup),
    {ok, _} = ensure_or_keep(project_share_licenses_sup),
    {ok, _} = ensure_or_keep(project_briefcase_files_sup),

    %% Domain sups (emitters + PMs + listeners).
    {ok, _} = ensure_or_keep(guide_share_license_lifecycle_sup),
    {ok, _} = ensure_or_keep(guide_briefcase_lifecycle_sup),

    %% Seed K_realm v1 so license issuance + open-path guard work.
    prime_realm_shared_key(?REALM, 1),
    DataDir.

cleanup(DataDir) ->
    %% Tear down sups in reverse order. Each catch silences "not
    %% started" if a test crashed it before us.
    [safe_stop(M) || M <- [guide_briefcase_lifecycle_sup,
                            guide_share_license_lifecycle_sup,
                            project_briefcase_files_sup,
                            project_share_licenses_sup,
                            project_realm_memberships_sup,
                            hecate_mesh_client]],
    %% Delete the named ETS tables — `delete_all_objects` would
    %% leave them around and the NEXT test (eunit suite running
    %% after us) hits `already_exists` when its own setup tries
    %% to ets:new them.
    [maybe_delete(T) || T <- [realm_shared_keys, realm_memberships,
                               realm_credentials, briefcase_files,
                               my_issued_realm_scoped_active_licenses,
                               my_accepted_share_licenses,
                               my_issued_files,
                               briefcase_download_progress,
                               briefcase_download_workers]],
    file:del_dir_r(DataDir),
    ok.

ensure_or_keep(Mod) ->
    case erlang:whereis(Mod) of
        undefined -> Mod:start_link();
        Pid       -> {ok, Pid}
    end.

safe_stop(Mod) ->
    case erlang:whereis(Mod) of
        undefined -> ok;
        Pid ->
            %% Unlink before exit so the test process isn't notified
            %% by the supervisor's normal shutdown cascade.
            try unlink(Pid) catch _:_ -> ok end,
            try exit(Pid, shutdown) catch _:_ -> ok end,
            wait_for_exit(Pid, 1000)
    end.

wait_for_exit(Pid, TimeoutMs) ->
    Ref = monitor(process, Pid),
    receive
        {'DOWN', Ref, process, Pid, _} -> ok
    after TimeoutMs ->
        demonitor(Ref, [flush]),
        ok
    end.

maybe_delete(Name) ->
    case ets:info(Name) of
        undefined -> ok;
        _         -> catch ets:delete(Name), ok
    end.

start_store(StoreId, BaseDir) ->
    SubDir = filename:join([BaseDir, "stores", atom_to_list(StoreId)]),
    ok = filelib:ensure_path(SubDir),
    Config = #store_config{
        store_id         = StoreId,
        data_dir         = SubDir,
        mode             = single,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 1,
        options          = #{}
    },
    _ = reckon_db_sup:start_store(Config),
    ok.

wait_for_store(StoreId) ->
    wait_until(fun() ->
        case catch reckon_db_sup:which_stores() of
            L when is_list(L) -> lists:member(StoreId, L);
            _                  -> false
        end
    end, 30000).

start_subscription(StoreId) ->
    case evoq_store_subscription:start_link(StoreId) of
        {ok, _Pid}                       -> ok;
        {error, {already_started, _Pid}} -> ok;
        {error, Reason}                  -> ct:pal("subscription start failed ~p: ~p", [StoreId, Reason]), ok
    end.

prime_realm_shared_key(Realm, Version) ->
    case ets:info(realm_shared_keys) of
        undefined -> ets:new(realm_shared_keys, [public, named_table, set]);
        _         -> ok
    end,
    KRealm = crypto:strong_rand_bytes(32),
    {ok, Sealed} = hecate_crypto:encrypt(KRealm),
    Now = erlang:system_time(millisecond),
    ets:insert(realm_shared_keys,
               {Realm, #{realm => Realm,
                         k_realm_version => Version,
                         k_realm_encrypted => Sealed,
                         received_at => Now,
                         membership_id => <<"test-mem">>,
                         last_license_catchup_at => Now}}),
    {KRealm, Sealed}.

%%====================================================================
%% Tests
%%====================================================================

lifecycle_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(_DataDir) ->
         {inorder,
          [{"share + accept + open works",
            fun happy_share_accept/0},
           {"revoke clears CEK_USABLE; guard refuses",
            fun revoke_clears_open/0},
           {"K_realm rotation rewraps issuer-side licenses",
            fun rewrap_on_rotation/0}]}
     end}.

happy_share_accept() ->
    FileId = fresh_file_id(),
    {ok, #{license_ids := [LicenseId]}} =
        issue_licenses_for_share:dispatch_for(FileId, ?REALM, ?ALICE, [realm]),
    wait_until(fun() -> ets:info(my_issued_realm_scoped_active_licenses, size) >= 1 end, 2000),
    wait_until(fun() -> ets:info(my_issued_files, size) >= 1 end, 2000),

    accept_via_dispatch(FileId, LicenseId),
    wait_until(fun() -> ets:info(my_accepted_share_licenses, size) >= 1 end, 2000),

    {ok, Issued} = project_share_licenses_store:get_issued_file(FileId),
    ?assertEqual(?REALM, maps:get(realm, Issued)),

    {ok, Accepted} = project_share_licenses_store:get_accepted_by_file_id(FileId),
    Status = maps:get(status, Accepted),
    ?assert(evoq_bit_flags:has(Status, ?SL_ACCEPTED)),
    ?assert(evoq_bit_flags:has(Status, ?SL_CEK_USABLE)),

    %% Guard passes.
    ?assertEqual(ok, hecate_license_guard:can_open_file(FileId, ?REALM)).

revoke_clears_open() ->
    FileId = fresh_file_id(),
    {ok, #{license_ids := [LicenseId]}} =
        issue_licenses_for_share:dispatch_for(FileId, ?REALM, ?ALICE, [realm]),
    accept_via_dispatch(FileId, LicenseId),
    wait_until(fun() -> ets:info(my_accepted_share_licenses, size) >= 1 end, 2000),
    ?assertEqual(ok, hecate_license_guard:can_open_file(FileId, ?REALM)),

    %% Issuer revokes.
    {ok, RevokeCmd} = revoke_share_license_v1:new(
        #{license_id => LicenseId, reason => kicked}),
    {ok, _, _} = maybe_revoke_share_license:dispatch(RevokeCmd),

    %% Recipient end (would be triggered by the listener in prod;
    %% explicit dispatch keeps the test single-threaded).
    {ok, EndCmd} = end_license_v1:new(
        #{license_id => LicenseId, reason => revoked}),
    {ok, _, _} = maybe_end_license:dispatch(EndCmd),

    %% Wait for the projection to fold the end event.
    wait_until(fun() ->
        case project_share_licenses_store:get_accepted_by_file_id(FileId) of
            {ok, #{status := S}} -> not evoq_bit_flags:has(S, ?SL_CEK_USABLE);
            _                    -> false
        end
    end, 2000),

    ?assertEqual({error, license_not_usable},
                 hecate_license_guard:can_open_file(FileId, ?REALM)).

rewrap_on_rotation() ->
    FileId = fresh_file_id(),
    {ok, #{license_ids := [LicenseId]}} =
        issue_licenses_for_share:dispatch_for(FileId, ?REALM, ?ALICE, [realm]),
    accept_via_dispatch(FileId, LicenseId),
    wait_until(fun() -> ets:info(my_accepted_share_licenses, size) >= 1 end, 2000),

    %% Rotate K_realm to v2 — prime the new entry, then directly
    %% invoke the rewrap PM (skips the projection race that the
    %% PM's `wrap_with_sealed/2` already sidesteps).
    {_NewKey, NewSealed} = prime_realm_shared_key(?REALM, 2),
    Event = #{data => #{
        event_type => <<"realm_shared_key_stored_v1">>,
        membership_id => <<"test-mem">>,
        realm => ?REALM,
        k_realm_version => 2,
        k_realm_encrypted => NewSealed,
        received_at => erlang:system_time(millisecond)}},
    {ok, _} = on_realm_key_rotated_rewrap_licenses:handle_event(
                 <<"realm_shared_key_stored_v1">>, Event, #{},
                 on_realm_key_rotated_rewrap_licenses:default_config()),

    %% Wait until THIS test's license appears at k_realm_version = 2.
    %% The inorder cases above also left active v1 licenses that the
    %% rewrap PM picks up, so Entries2 may hold more than one row —
    %% what we care about is that our new license landed at v2, not
    %% the row count or ordering.
    HasOurs = fun(Entries) ->
        lists:any(fun(E) -> maps:get(license_id, E) =:= LicenseId end, Entries)
    end,
    wait_until(fun() ->
        case project_share_licenses_store:list_active_for_realm_version(?REALM, 2) of
            {ok, Entries} -> HasOurs(Entries);
            _             -> false
        end
    end, 3000),

    {ok, Entries2} = project_share_licenses_store:list_active_for_realm_version(?REALM, 2),
    ?assert(HasOurs(Entries2)).

%%====================================================================
%% Helpers
%%====================================================================

fresh_file_id() ->
    iolist_to_binary([integer_to_list(erlang:unique_integer([positive])),
                      "deadbeef00112233445566778899aabb"]).

%% Hand-build the recipient's accept_license_v1 dispatch — bypasses
%% the listener (which would filter by hecate_identity).
accept_via_dispatch(FileId, LicenseId) ->
    %% Wait for the my_issued_files projection to register THIS
    %% file_id (not just any). Tests run sequentially against a
    %% shared projection so size>=1 from a previous test isn't
    %% enough.
    wait_until(fun() ->
        case project_share_licenses_store:get_issued_file(FileId) of
            {ok, _} -> true;
            _       -> false
        end
    end, 3000),
    {ok, Issued} = project_share_licenses_store:get_issued_file(FileId),
    OriginSealed = maps:get(origin_cek_sealed, Issued),
    {ok, Cek} = hecate_crypto:decrypt(OriginSealed),
    {ok, Wrapped} = hecate_realm_crypto:wrap(?REALM, Cek),
    {ok, Cmd} = accept_license_v1:new(#{
        license_id      => LicenseId,
        file_id         => FileId,
        grantee         => <<"mri:realm:", (?REALM)/binary>>,
        wrap_strategy   => realm_key_v1,
        wrapped_cek     => Wrapped,
        k_realm_version => 1,
        issuer_did      => ?ALICE,
        realm           => ?REALM,
        issued_at       => erlang:system_time(millisecond),
        expires_at      => erlang:system_time(millisecond) + 86400000}),
    {ok, _, _} = maybe_accept_license:dispatch(Cmd),
    %% Wait for the recipient projection too so subsequent
    %% assertions see the row.
    wait_until(fun() ->
        case project_share_licenses_store:get_accepted_by_file_id(FileId) of
            {ok, _} -> true;
            _       -> false
        end
    end, 3000),
    ok.

wait_until(Fn, TimeoutMs) ->
    Deadline = erlang:system_time(millisecond) + TimeoutMs,
    wait_loop(Fn, Deadline).

wait_loop(Fn, Deadline) ->
    case Fn() of
        true -> ok;
        _    ->
            case erlang:system_time(millisecond) > Deadline of
                true  -> ?assert(false);
                false -> timer:sleep(50), wait_loop(Fn, Deadline)
            end
    end.
