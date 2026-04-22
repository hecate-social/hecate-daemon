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

alice_share_bob_download_open(_Config) ->
    %% Skeleton — full implementation needs:
    %%   1. POST /api/briefcase/files/upload on Alice (multipart).
    %%   2. POST /api/briefcase/files/:id/share on Alice.
    %%   3. fleet_wait:for_state(Bob, "/api/briefcase/files/:id",
    %%        <<"presence">>, <<"remote">>).
    %%   4. POST /api/briefcase/files/:id/download on Bob.
    %%   5. fleet_wait:for_state(Bob, "/api/briefcase/files/:id/download",
    %%        <<"state">>, <<"completed">>).
    %%   6. GET /api/briefcase/files/:id/content on Bob → assert
    %%      plaintext matches the upload.
    %%
    %% Multipart upload via curl needs a tempfile on the SSH target
    %% (curl --form). Helper for that lands in fleet_daemon:upload/3
    %% as a follow-up.
    {skip, "scenario harness pending — needs multipart upload helper"}.

revoke_clears_open(_Config) ->
    %% Skeleton — depends on alice_share_bob_download_open scaffolding.
    {skip, "depends on share/download scenario — pending"}.

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
    case fleet_daemon:get(D, <<"/api/health">>) of
        {200, _}    -> ping_all(Rest);
        {Status, _} -> {error, {bad_status, D, Status}};
        Other       -> {error, {Other, D}}
    end.

%% (ct.hrl include_lib at top supplies ?assertMatch / ?assertEqual /
%% ct:fail/1 used above.)
