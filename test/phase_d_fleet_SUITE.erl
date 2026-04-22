%%% @doc Real-fleet CT suite for Phase D + E + F.
%%%
%%% Drives the actual beam cluster (beam00-03) over SSH + curl
%%% against each daemon's local Unix socket. Requires:
%%%
%%%   - SSH key configured on the operator's machine for each beam
%%%     node (passwordless).
%%%   - Each daemon has `HECATE_ADMIN_TOKEN` set to a known value.
%%%   - macula-realm reachable + has its admin endpoints enabled.
%%%   - A fleet config file at `test/fleet/fleet.config` describing
%%%     the topology — see `fleet_config.erl` for the shape.
%%%
%%% If any prerequisite is missing, `init_per_suite` skips the entire
%%% suite cleanly so this stays out of CI's hair.
%%%
%%% Run manually:
%%%   HECATE_FLEET_CONFIG=path/to/fleet.config \
%%%     rebar3 ct --suite test/fleet/phase_d_fleet_SUITE
%%% @end
-module(phase_d_fleet_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([smoke_admin_guard_responds/1,
         alice_share_bob_download_open/1,
         revoke_clears_open/1]).

all() ->
    [smoke_admin_guard_responds,
     alice_share_bob_download_open,
     revoke_clears_open].

init_per_suite(Config) ->
    case fleet_config:load() of
        {ok, FleetConfig} ->
            case verify_reachable(FleetConfig) of
                ok ->
                    [{fleet_config, FleetConfig} | Config];
                {error, Reason} ->
                    {skip, {fleet_unreachable, Reason}}
            end;
        {error, no_config} ->
            {skip, "fleet config not provided — set HECATE_FLEET_CONFIG"};
        {error, Reason} ->
            {skip, {bad_fleet_config, Reason}}
    end.

end_per_suite(_Config) -> ok.

%%====================================================================
%% Tests
%%====================================================================

smoke_admin_guard_responds(Config) ->
    %% Lightest possible test — verify each daemon answers admin
    %% requests at all. Catches: bad token config, sockets not
    %% mounted, daemon not running.
    FleetConfig = ?config(fleet_config, Config),
    Token = fleet_config:admin_token(FleetConfig),
    Realm = fleet_config:realm(FleetConfig),
    Daemons = maps:get(daemons, FleetConfig, []),

    lists:foreach(
        fun(D) ->
            %% Hit guard endpoint with a made-up file_id; expect 200
            %% with state=refused (no_license).
            Path = <<"/api/admin/briefcase/guard/no-such-file?realm=",
                     Realm/binary>>,
            {Status, Body} = fleet_daemon:get(D, Path,
                [{<<"Authorization">>, <<"Bearer ", Token/binary>>}]),
            ?assertEqual(200, Status),
            Decoded = json:decode(Body),
            ?assertMatch(#{<<"guard">> := #{<<"state">> := <<"refused">>}},
                         Decoded)
        end, Daemons).

alice_share_bob_download_open(Config) ->
    FleetConfig = ?config(fleet_config, Config),
    {ok, Alice} = fleet_config:daemon(FleetConfig, alice),
    {ok, Bob}   = fleet_config:daemon(FleetConfig, bob),
    Token = fleet_config:admin_token(FleetConfig),

    %% Generate a unique payload + temp file local to the test runner.
    %% `unique_integer` resets each VM start, so include wall-clock
    %% microseconds to guarantee uniqueness across CT reruns. Otherwise
    %% identical content yields the same content-addressed file_id and
    %% the daemon's persistent aggregate rejects it as `already_uploaded`.
    Nonce = integer_to_binary(os:system_time(microsecond)),
    Payload = <<"phase-d-fleet-payload-", Nonce/binary, "-",
                (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    LocalPath = "/tmp/phase_d_fleet_" ++
                binary_to_list(Nonce) ++ "_" ++
                integer_to_list(erlang:unique_integer([positive])) ++
                ".txt",
    ok = file:write_file(LocalPath, Payload),

    try
        %% 1. Alice uploads.
        {200, UploadBody} =
            fleet_daemon:upload(Alice, LocalPath,
                                <<"phase-d-fleet.txt">>,
                                <<"text/plain">>),
        #{<<"file_id">> := FileId} = json:decode(UploadBody),
        ct:pal("Alice uploaded file_id=~s", [FileId]),

        %% 1b. Wait for Alice's own briefcase projection to register
        %% the file. `consistency: eventual` on upload dispatch means
        %% the HTTP 200 can race ahead of the event reaching the
        %% briefcase aggregate's store, producing
        %% {wrong_expected_version, 0, -1} on the subsequent share
        %% append.
        ok = fleet_wait:for_state(Alice,
            <<"/api/briefcase/files/", FileId/binary>>,
            <<"presence">>, <<"local">>),

        %% 2. Alice shares to realm.
        ShareBody = json:encode(#{<<"recipients">> => <<"realm">>}),
        {200, _} =
            fleet_daemon:post(Alice,
                <<"/api/briefcase/files/", FileId/binary, "/share">>,
                ShareBody),

        %% 3. Wait for Bob's projection to show the placeholder.
        ok = fleet_wait:for_state(Bob,
            <<"/api/briefcase/files/", FileId/binary>>,
            <<"presence">>, <<"remote">>),
        ct:pal("Bob sees placeholder for file_id=~s", [FileId]),

        %% 4. Bob initiates download.
        {Status, _} =
            fleet_daemon:post(Bob,
                <<"/api/briefcase/files/", FileId/binary, "/download">>,
                #{}),
        true = lists:member(Status, [200, 202]),

        %% 5. Wait for Bob's progress endpoint to report completed.
        ok = fleet_wait:for_state(Bob,
            <<"/api/briefcase/files/", FileId/binary, "/download">>,
            <<"state">>, <<"completed">>),
        ct:pal("Bob completed download of file_id=~s", [FileId]),

        %% 6. Open + verify plaintext matches.
        {200, OpenedBody} =
            fleet_daemon:get(Bob,
                <<"/api/briefcase/files/", FileId/binary, "/content">>),
        ?assertEqual(Payload, OpenedBody),
        ct:pal("Bob opened file_id=~s — content matches", [FileId]),

        %% 7. Admin guard inspect should report state=ok.
        AuthHeader = [{<<"Authorization">>, <<"Bearer ", Token/binary>>}],
        Realm = fleet_config:realm(FleetConfig),
        {200, GuardBody} =
            fleet_daemon:get(Bob,
                <<"/api/admin/briefcase/guard/", FileId/binary,
                  "?realm=", Realm/binary>>,
                AuthHeader),
        ?assertMatch(#{<<"guard">> := #{<<"state">> := <<"ok">>}},
                     json:decode(GuardBody))
    after
        file:delete(LocalPath)
    end.

revoke_clears_open(Config) ->
    FleetConfig = ?config(fleet_config, Config),
    {ok, Alice} = fleet_config:daemon(FleetConfig, alice),
    {ok, Bob}   = fleet_config:daemon(FleetConfig, bob),
    Token = fleet_config:admin_token(FleetConfig),
    Realm = fleet_config:realm(FleetConfig),
    AuthHeader = [{<<"Authorization">>, <<"Bearer ", Token/binary>>}],

    %% Replay the share + accept flow, then revoke.
    %% See alice_share_bob_download_open for why we mix microseconds
    %% with unique_integer — guarantees cross-VM-start uniqueness.
    Nonce = integer_to_binary(os:system_time(microsecond)),
    Payload = <<"revoke-test-payload-", Nonce/binary, "-",
                (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    LocalPath = "/tmp/phase_d_revoke_" ++
                binary_to_list(Nonce) ++ "_" ++
                integer_to_list(erlang:unique_integer([positive])) ++
                ".txt",
    ok = file:write_file(LocalPath, Payload),

    try
        {200, UploadBody} =
            fleet_daemon:upload(Alice, LocalPath,
                                <<"revoke-test.txt">>,
                                <<"text/plain">>),
        %% Upload response: #{ok, file_id, path, size}. The license_id
        %% only appears on the share response, not upload.
        #{<<"file_id">> := FileId} = json:decode(UploadBody),

        %% Bridge the eventual-consistency window between upload and
        %% share — see alice_share_bob_download_open for the rationale.
        ok = fleet_wait:for_state(Alice,
            <<"/api/briefcase/files/", FileId/binary>>,
            <<"presence">>, <<"local">>),

        ShareBody = json:encode(#{<<"recipients">> => <<"realm">>}),
        {200, ShareResp} =
            fleet_daemon:post(Alice,
                <<"/api/briefcase/files/", FileId/binary, "/share">>,
                ShareBody),
        %% The share response carries license_ids (the issuer side
        %% knows them); we want the one Bob accepts (realm-scope).
        #{<<"license_ids">> := [LicenseIdFromShare | _]} = json:decode(ShareResp),

        ok = fleet_wait:for_state(Bob,
            <<"/api/briefcase/files/", FileId/binary>>,
            <<"presence">>, <<"remote">>),

        %% Alice revokes.
        RevokeBody = json:encode(#{<<"reason">> => <<"test">>}),
        {Status, _} =
            fleet_daemon:post(Alice,
                <<"/api/briefcase/share-licenses/",
                  LicenseIdFromShare/binary, "/revoke">>,
                RevokeBody),
        true = lists:member(Status, [200, 202, 204]),

        %% Wait for Bob's guard to flip to refused.
        ok = fleet_wait:until(fun() ->
            case fleet_daemon:get(Bob,
                    <<"/api/admin/briefcase/guard/", FileId/binary,
                      "?realm=", Realm/binary>>,
                    AuthHeader) of
                {200, GuardBody} ->
                    case json:decode(GuardBody) of
                        #{<<"guard">> := #{<<"state">> := <<"refused">>}} -> true;
                        _ -> false
                    end;
                _ -> false
            end
        end, 30000),

        %% Open should now return 403.
        {OpenStatus, _} =
            fleet_daemon:get(Bob,
                <<"/api/briefcase/files/", FileId/binary, "/content">>),
        ?assertEqual(403, OpenStatus)
    after
        file:delete(LocalPath)
    end.

%%====================================================================
%% Internal
%%====================================================================

verify_reachable(FleetConfig) ->
    Daemons = maps:get(daemons, FleetConfig, []),
    case Daemons of
        [] -> {error, no_daemons_in_config};
        _  -> ping_all(Daemons)
    end.

ping_all([]) -> ok;
ping_all([D | Rest]) ->
    case fleet_daemon:get(D, <<"/health">>) of
        {200, _}    -> ping_all(Rest);
        {Status, _} -> {error, {bad_status, D, Status}};
        Other       -> {error, {Other, D}}
    end.

%% (ct.hrl include_lib at top supplies ?assertMatch / ?assertEqual /
%% ct:fail/1 used above.)
