%%% @doc Tests for the license_aggregate.
%%%
%%% Tests the full lifecycle:
%%%   Initiate -> Announce -> Publish -> Buy ->
%%%   Revoke -> Archive
%%%
%%% Also tests business rules (invalid transitions, guards).
-module(license_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include("license_status.hrl").
-include("license_state.hrl").

-define(LICENSE_ID, <<"license-seller-1-hecate-social/trader">>).
-define(PLUGIN_ID, <<"hecate-social/trader">>).
-define(SELLER_ID, <<"seller-1">>).
-define(USER_ID, <<"buyer-1">>).

%% ── Test Helpers ────────────────────────────────────────────────────────────

fresh_state() ->
    license_aggregate:initial_state().

make_initiate_payload() ->
    #{
        <<"command_type">> => <<"initiate_license">>,
        <<"plugin_id">> => ?PLUGIN_ID,
        <<"plugin_name">> => <<"Trader">>,
        <<"description">> => <<"Trading bot plugin">>,
        <<"icon">> => <<"trader.svg">>,
        <<"github_repo">> => <<"hecate-social/hecate-trader">>,
        <<"oci_image">> => <<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>,
        <<"selling_formula">> => <<"free">>,
        <<"seller_id">> => ?SELLER_ID,
        <<"org">> => <<"hecate-social">>,
        <<"version">> => <<"0.1.0">>,
        <<"manifest_tag">> => <<"v0.1.0">>,
        <<"tags">> => <<"[\"trading\",\"bot\"]">>,
        <<"homepage">> => <<"https://hecate.social/plugins/trader">>,
        <<"min_daemon_version">> => <<"0.8.0">>,
        <<"publisher_identity">> => <<"did:key:z6Mk...">>
    }.

make_announce_payload() ->
    #{
        <<"command_type">> => <<"announce_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

make_publish_payload() ->
    #{
        <<"command_type">> => <<"publish_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

make_buy_payload() ->
    #{
        <<"command_type">> => <<"buy_license">>,
        <<"license_id">> => ?LICENSE_ID,
        <<"user_id">> => ?USER_ID,
        <<"plugin_id">> => ?PLUGIN_ID,
        <<"oci_image">> => <<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>
    }.

make_revoke_payload() ->
    #{
        <<"command_type">> => <<"revoke_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

make_archive_payload() ->
    #{
        <<"command_type">> => <<"archive_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

%% Execute a command and apply the resulting events to the state
execute_and_apply(State, Payload) ->
    case license_aggregate:execute(State, Payload) of
        {ok, EventMaps} ->
            NewState = lists:foldl(
                fun(E, S) -> license_aggregate:apply(S, E) end,
                State,
                EventMaps
            ),
            {ok, NewState, EventMaps};
        {error, _} = Err ->
            Err
    end.

%% ── Initial State Tests ────────────────────────────────────────────────────

initial_state_test() ->
    S = fresh_state(),
    ?assertEqual(0, S#license_state.status),
    ?assertEqual(undefined, S#license_state.license_id).

%% ── Seller Lifecycle Tests ─────────────────────────────────────────────────

initiate_from_fresh_test() ->
    {ok, S, _Events} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assertNotEqual(0, S#license_state.status band ?LIC_INITIATED),
    ?assertEqual(?PLUGIN_ID, S#license_state.plugin_id),
    ?assertEqual(?SELLER_ID, S#license_state.seller_id),
    ?assertEqual(<<"Trader">>, S#license_state.plugin_name).

announce_after_initiate_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    ?assertNotEqual(0, S2#license_state.status band ?LIC_ANNOUNCED),
    ?assertNotEqual(undefined, S2#license_state.announced_at).

publish_after_announce_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    ?assertNotEqual(0, S3#license_state.status band ?LIC_PUBLISHED),
    ?assertNotEqual(undefined, S3#license_state.published_at).

%% ── Buyer Lifecycle Tests ──────────────────────────────────────────────────

buy_after_publish_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    {ok, S4, _} = execute_and_apply(S3, make_buy_payload()),
    ?assertNotEqual(0, S4#license_state.status band ?LIC_LICENSED),
    ?assertEqual(?USER_ID, S4#license_state.user_id).

revoke_after_buy_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    {ok, S4, _} = execute_and_apply(S3, make_buy_payload()),
    {ok, S5, _} = execute_and_apply(S4, make_revoke_payload()),
    ?assertNotEqual(0, S5#license_state.status band ?LIC_REVOKED).

archive_after_revoke_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    {ok, S4, _} = execute_and_apply(S3, make_buy_payload()),
    {ok, S5, _} = execute_and_apply(S4, make_revoke_payload()),
    {ok, S6, _} = execute_and_apply(S5, make_archive_payload()),
    ?assertNotEqual(0, S6#license_state.status band ?LIC_ARCHIVED).

%% ── Business Rule Tests (invalid transitions) ─────────────────────────────

cannot_buy_from_fresh_test() ->
    Result = license_aggregate:execute(fresh_state(), make_buy_payload()),
    ?assertEqual({error, license_not_initiated}, Result).

cannot_announce_from_fresh_test() ->
    Result = license_aggregate:execute(fresh_state(), make_announce_payload()),
    ?assertEqual({error, license_not_initiated}, Result).

cannot_buy_before_publish_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    %% Announced but not published — cannot buy
    Result = license_aggregate:execute(S2, make_buy_payload()),
    ?assertEqual({error, not_published}, Result).

cannot_act_on_archived_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    {ok, S4, _} = execute_and_apply(S3, make_buy_payload()),
    {ok, S5, _} = execute_and_apply(S4, make_revoke_payload()),
    {ok, S6, _} = execute_and_apply(S5, make_archive_payload()),
    %% Archived — nothing allowed
    Result = license_aggregate:execute(S6, make_buy_payload()),
    ?assertEqual({error, license_archived}, Result).

revoked_only_allows_archive_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    {ok, S4, _} = execute_and_apply(S3, make_buy_payload()),
    {ok, S5, _} = execute_and_apply(S4, make_revoke_payload()),
    %% Revoked — only archive allowed
    ?assertEqual({error, license_revoked},
                 license_aggregate:execute(S5, make_buy_payload())),
    %% But archive should work
    {ok, _S6, _} = execute_and_apply(S5, make_archive_payload()).

%% ── Event Content Tests ────────────────────────────────────────────────────

initiate_event_has_correct_type_test() ->
    {ok, _S, [Event]} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assertEqual(<<"license_initiated_v1">>,
                 maps:get(<<"event_type">>, Event)).

announce_event_has_correct_type_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, _S2, [Event]} = execute_and_apply(S1, make_announce_payload()),
    ?assertEqual(<<"license_announced_v1">>,
                 maps:get(<<"event_type">>, Event)).

publish_event_has_correct_type_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, _S3, [Event]} = execute_and_apply(S2, make_publish_payload()),
    ?assertEqual(<<"license_published_v1">>,
                 maps:get(<<"event_type">>, Event)).

%% ── Bit Flag Tests ─────────────────────────────────────────────────────────

flag_map_test() ->
    Map = license_aggregate:flag_map(),
    ?assertEqual(<<"Initiated">>, maps:get(1, Map)),
    ?assertEqual(<<"Announced">>, maps:get(2, Map)),
    ?assertEqual(<<"Published">>, maps:get(4, Map)),
    ?assertEqual(<<"Licensed">>, maps:get(8, Map)).

full_lifecycle_flags_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assertEqual(?LIC_INITIATED, S1#license_state.status),

    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    ?assertEqual(?LIC_INITIATED bor ?LIC_ANNOUNCED, S2#license_state.status),

    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    ?assertEqual(?LIC_INITIATED bor ?LIC_ANNOUNCED bor ?LIC_PUBLISHED,
                 S3#license_state.status),

    {ok, S4, _} = execute_and_apply(S3, make_buy_payload()),
    ?assertEqual(?LIC_INITIATED bor ?LIC_ANNOUNCED bor ?LIC_PUBLISHED bor ?LIC_LICENSED,
                 S4#license_state.status).

%% ── New Metadata Tests ───────────────────────────────────────────────────────

initiate_sets_new_metadata_test() ->
    {ok, S, _Events} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assertEqual(<<"hecate-social">>, S#license_state.org),
    ?assertEqual(<<"0.1.0">>, S#license_state.version),
    ?assertEqual(<<"v0.1.0">>, S#license_state.manifest_tag),
    ?assertEqual(<<"[\"trading\",\"bot\"]">>, S#license_state.tags),
    ?assertEqual(<<"https://hecate.social/plugins/trader">>, S#license_state.homepage),
    ?assertEqual(<<"0.8.0">>, S#license_state.min_daemon_version),
    ?assertEqual(<<"did:key:z6Mk...">>, S#license_state.publisher_identity).

archive_sets_archived_at_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    {ok, S4, _} = execute_and_apply(S3, make_buy_payload()),
    {ok, S5, _} = execute_and_apply(S4, make_revoke_payload()),
    {ok, S6, _} = execute_and_apply(S5, make_archive_payload()),
    ?assertNotEqual(undefined, S6#license_state.archived_at),
    ?assert(is_integer(S6#license_state.archived_at)).
