%%% @doc Tests for the license_offering_aggregate (author side).
%%%
%%% Tests the full lifecycle:
%%%   Initiate -> Announce -> Publish -> Retract -> Archive
%%%
%%% Also tests amend (partial updates) and business rules.
-module(license_offering_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include("offering_status.hrl").
-include("offering_state.hrl").

-define(AUTHOR_ID, <<"author-1">>).
-define(PLUGIN_ID, <<"hecate-social/trader">>).
-define(OFFERING_ID, <<"offering-author-1-hecate-social/trader">>).

%% ── Test Helpers ────────────────────────────────────────────────────────────

fresh_state() ->
    license_offering_aggregate:initial_state().

make_initiate_payload() ->
    #{
        <<"command_type">> => <<"initiate_offering">>,
        <<"plugin_id">> => ?PLUGIN_ID,
        <<"author_id">> => ?AUTHOR_ID,
        <<"plugin_name">> => <<"Trader">>,
        <<"description">> => <<"Trading bot plugin">>,
        <<"icon">> => <<"trader.svg">>,
        <<"group_name">> => <<"Trading">>,
        <<"github_repo">> => <<"hecate-social/hecate-trader">>,
        <<"oci_image">> => <<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>,
        <<"selling_formula">> => <<"free">>,
        <<"license_type">> => <<"free">>,
        <<"fee_cents">> => 0,
        <<"fee_currency">> => <<"EUR">>,
        <<"duration_days">> => 0,
        <<"node_limit">> => 0,
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
        <<"command_type">> => <<"announce_offering">>,
        <<"offering_id">> => ?OFFERING_ID
    }.

make_publish_payload() ->
    #{
        <<"command_type">> => <<"publish_offering">>,
        <<"offering_id">> => ?OFFERING_ID
    }.

make_retract_payload() ->
    #{
        <<"command_type">> => <<"retract_offering">>,
        <<"offering_id">> => ?OFFERING_ID
    }.

make_amend_payload() ->
    #{
        <<"command_type">> => <<"amend_offering">>,
        <<"offering_id">> => ?OFFERING_ID,
        <<"description">> => <<"Pro trading bot">>,
        <<"oci_image">> => <<"ghcr.io/hecate-social/hecate-traderd:0.2.0">>,
        <<"fee_cents">> => 999,
        <<"license_type">> => <<"subscription">>
    }.

make_archive_payload() ->
    #{
        <<"command_type">> => <<"archive_offering">>,
        <<"offering_id">> => ?OFFERING_ID
    }.

execute_and_apply(State, Payload) ->
    case license_offering_aggregate:execute(State, Payload) of
        {ok, EventMaps} ->
            NewState = lists:foldl(
                fun(E, S) -> license_offering_aggregate:apply(S, E) end,
                State,
                EventMaps
            ),
            {ok, NewState, EventMaps};
        {error, _} = Err ->
            Err
    end.

state_initiated() ->
    {ok, S, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    S.

state_announced() ->
    {ok, S, _} = execute_and_apply(state_initiated(), make_announce_payload()),
    S.

state_published() ->
    {ok, S, _} = execute_and_apply(state_announced(), make_publish_payload()),
    S.

status(S) -> S#offering_state.status.

%% ── Initial State Tests ────────────────────────────────────────────────────

initial_state_test() ->
    S = fresh_state(),
    ?assertEqual(0, status(S)),
    ?assertEqual(undefined, S#offering_state.offering_id).

%% ── Author Lifecycle Tests (Happy Path) ────────────────────────────────────

initiate_from_fresh_test() ->
    {ok, S, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?OFF_INITIATED)),
    ?assertEqual(?PLUGIN_ID, S#offering_state.plugin_id),
    ?assertEqual(?AUTHOR_ID, S#offering_state.author_id),
    ?assertEqual(<<"Trader">>, S#offering_state.plugin_name),
    ?assertEqual(<<"Trading bot plugin">>, S#offering_state.description),
    ?assertNotEqual(undefined, S#offering_state.initiated_at).

announce_after_initiate_test() ->
    {ok, S, _} = execute_and_apply(state_initiated(), make_announce_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?OFF_ANNOUNCED)),
    ?assertNotEqual(undefined, S#offering_state.announced_at).

publish_after_announce_test() ->
    {ok, S, _} = execute_and_apply(state_announced(), make_publish_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?OFF_PUBLISHED)),
    ?assertNotEqual(undefined, S#offering_state.published_at).

retract_after_publish_test() ->
    {ok, S, _} = execute_and_apply(state_published(), make_retract_payload()),
    %% Retract resets to INITIATED only
    ?assertEqual(?OFF_INITIATED, status(S)),
    ?assert(evoq_bit_flags:has_not(status(S), ?OFF_PUBLISHED)),
    ?assert(evoq_bit_flags:has_not(status(S), ?OFF_ANNOUNCED)),
    ?assertNotEqual(undefined, S#offering_state.retracted_at).

republish_after_retract_test() ->
    {ok, S1, _} = execute_and_apply(state_published(), make_retract_payload()),
    %% After retract, can announce again
    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    ?assert(evoq_bit_flags:has(status(S2), ?OFF_ANNOUNCED)),
    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    ?assert(evoq_bit_flags:has(status(S3), ?OFF_PUBLISHED)).

archive_after_publish_test() ->
    {ok, S, _} = execute_and_apply(state_published(), make_archive_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?OFF_ARCHIVED)),
    ?assertNotEqual(undefined, S#offering_state.archived_at).

%% ── Amend Tests ────────────────────────────────────────────────────────────

amend_after_initiate_test() ->
    {ok, S, [Event]} = execute_and_apply(state_initiated(), make_amend_payload()),
    ?assertEqual(<<"Pro trading bot">>, S#offering_state.description),
    ?assertEqual(<<"ghcr.io/hecate-social/hecate-traderd:0.2.0">>, S#offering_state.oci_image),
    ?assertEqual(999, S#offering_state.fee_cents),
    ?assertEqual(<<"subscription">>, S#offering_state.license_type),
    %% Non-amended fields preserved
    ?assertEqual(<<"Trader">>, S#offering_state.plugin_name),
    ?assertEqual(<<"free">>, S#offering_state.selling_formula),
    ?assertEqual(<<"offering_amended_v1">>, maps:get(event_type, Event)).

amend_after_announce_test() ->
    {ok, S, _} = execute_and_apply(state_announced(), make_amend_payload()),
    ?assertEqual(<<"Pro trading bot">>, S#offering_state.description).

amend_after_publish_test() ->
    {ok, S, _} = execute_and_apply(state_published(), make_amend_payload()),
    ?assertEqual(<<"Pro trading bot">>, S#offering_state.description).

%% ── Business Rule Tests (invalid transitions) ─────────────────────────────

cannot_announce_from_fresh_test() ->
    Result = license_offering_aggregate:execute(fresh_state(), make_announce_payload()),
    ?assertEqual({error, offering_not_initiated}, Result).

cannot_publish_from_fresh_test() ->
    Result = license_offering_aggregate:execute(fresh_state(), make_publish_payload()),
    ?assertEqual({error, offering_not_initiated}, Result).

cannot_publish_from_initiated_test() ->
    Result = license_offering_aggregate:execute(state_initiated(), make_publish_payload()),
    ?assertEqual({error, not_announced}, Result).

cannot_act_on_archived_test() ->
    {ok, Archived, _} = execute_and_apply(state_published(), make_archive_payload()),
    ?assertEqual({error, offering_archived},
                 license_offering_aggregate:execute(Archived, make_publish_payload())),
    ?assertEqual({error, offering_archived},
                 license_offering_aggregate:execute(Archived, make_amend_payload())).

%% ── Event Content Tests ────────────────────────────────────────────────────

initiate_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assertEqual(<<"offering_initiated_v1">>, maps:get(event_type, Event)).

announce_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_initiated(), make_announce_payload()),
    ?assertEqual(<<"offering_announced_v1">>, maps:get(event_type, Event)).

publish_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_announced(), make_publish_payload()),
    ?assertEqual(<<"offering_published_v1">>, maps:get(event_type, Event)).

retract_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_published(), make_retract_payload()),
    ?assertEqual(<<"offering_retracted_v1">>, maps:get(event_type, Event)).

archive_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_published(), make_archive_payload()),
    ?assertEqual(<<"offering_archived_v1">>, maps:get(event_type, Event)).

%% ── Bit Flag Tests ─────────────────────────────────────────────────────────

flag_map_test() ->
    Map = license_offering_aggregate:flag_map(),
    ?assertEqual(<<"Initiated">>, maps:get(1, Map)),
    ?assertEqual(<<"Announced">>, maps:get(2, Map)),
    ?assertEqual(<<"Published">>, maps:get(4, Map)),
    ?assertEqual(<<"Archived">>,  maps:get(32, Map)).

full_lifecycle_flags_test() ->
    S1 = state_initiated(),
    ?assertEqual(?OFF_INITIATED, status(S1)),

    {ok, S2, _} = execute_and_apply(S1, make_announce_payload()),
    ?assert(evoq_bit_flags:has_all(status(S2), [?OFF_INITIATED, ?OFF_ANNOUNCED])),

    {ok, S3, _} = execute_and_apply(S2, make_publish_payload()),
    ?assert(evoq_bit_flags:has_all(status(S3), [?OFF_INITIATED, ?OFF_ANNOUNCED, ?OFF_PUBLISHED])).

%% ── Initiate Sets All Fields Test ──────────────────────────────────────────

initiate_sets_all_fields_test() ->
    S = state_initiated(),
    ?assertEqual(?PLUGIN_ID, S#offering_state.plugin_id),
    ?assertEqual(?AUTHOR_ID, S#offering_state.author_id),
    ?assertEqual(<<"Trader">>, S#offering_state.plugin_name),
    ?assertEqual(<<"trader.svg">>, S#offering_state.icon),
    ?assertEqual(<<"Trading">>, S#offering_state.group_name),
    ?assertEqual(<<"hecate-social/hecate-trader">>, S#offering_state.github_repo),
    ?assertEqual(<<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>, S#offering_state.oci_image),
    ?assertEqual(<<"free">>, S#offering_state.selling_formula),
    ?assertEqual(<<"free">>, S#offering_state.license_type),
    ?assertEqual(0, S#offering_state.fee_cents),
    ?assertEqual(<<"EUR">>, S#offering_state.fee_currency),
    ?assertEqual(0, S#offering_state.duration_days),
    ?assertEqual(0, S#offering_state.node_limit),
    ?assertEqual(<<"hecate-social">>, S#offering_state.org),
    ?assertEqual(<<"0.1.0">>, S#offering_state.version),
    ?assertEqual(<<"v0.1.0">>, S#offering_state.manifest_tag),
    ?assertEqual(<<"https://hecate.social/plugins/trader">>, S#offering_state.homepage),
    ?assertEqual(<<"0.8.0">>, S#offering_state.min_daemon_version),
    ?assertEqual(<<"did:key:z6Mk...">>, S#offering_state.publisher_identity).
