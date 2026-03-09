%%% @doc Tests for the consumer license_aggregate.
%%%
%%% Tests the full consumer lifecycle:
%%%   Initiate -> Accept Terms -> Buy -> Grant ->
%%%   Expire -> Renew -> Revoke -> Archive
%%%
%%% Also tests: reject, abandon, free path (accept -> grant),
%%% and business rules (invalid transitions, guards).
-module(license_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include("license_status.hrl").
-include("license_state.hrl").

-define(CONSUMER_ID, <<"consumer-1">>).
-define(PLUGIN_ID, <<"hecate-social/trader">>).
-define(OFFERING_ID, <<"offering-author-1-hecate-social/trader">>).
-define(LICENSE_ID, <<"license-consumer-1-hecate-social/trader">>).

%% ── Test Helpers ────────────────────────────────────────────────────────────

fresh_state() ->
    license_aggregate:initial_state().

make_initiate_payload() ->
    #{
        <<"command_type">> => <<"initiate_license">>,
        <<"license_id">> => ?LICENSE_ID,
        <<"consumer_id">> => ?CONSUMER_ID,
        <<"plugin_id">> => ?PLUGIN_ID,
        <<"offering_id">> => ?OFFERING_ID,
        %% Full offering snapshot at birth
        <<"plugin_name">> => <<"Trader">>,
        <<"description">> => <<"Trading bot plugin">>,
        <<"icon">> => <<"trader.svg">>,
        <<"group_name">> => <<"Trading">>,
        <<"github_repo">> => <<"hecate-social/hecate-trader">>,
        <<"oci_image">> => <<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>,
        <<"selling_formula">> => <<"one_time">>,
        <<"author_id">> => <<"author-1">>,
        <<"license_type">> => <<"paid">>,
        <<"fee_cents">> => 999,
        <<"fee_currency">> => <<"EUR">>,
        <<"duration_days">> => 30,
        <<"node_limit">> => 3,
        <<"org">> => <<"hecate-social">>,
        <<"version">> => <<"0.1.0">>
    }.

make_initiate_free_payload() ->
    (make_initiate_payload())#{
        <<"selling_formula">> => <<"free">>,
        <<"license_type">> => <<"free">>,
        <<"fee_cents">> => 0
    }.

make_accept_payload() ->
    #{
        <<"command_type">> => <<"accept_offering_terms">>,
        <<"license_id">> => ?LICENSE_ID
    }.

make_reject_payload() ->
    #{
        <<"command_type">> => <<"reject_offering_terms">>,
        <<"license_id">> => ?LICENSE_ID,
        <<"rejection_reason">> => <<"too expensive">>
    }.

make_buy_payload() ->
    #{
        <<"command_type">> => <<"buy_license">>,
        <<"license_id">> => ?LICENSE_ID,
        <<"payment_reference">> => <<"pay-ref-123">>
    }.

make_abandon_payload() ->
    #{
        <<"command_type">> => <<"abandon_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

make_grant_payload() ->
    #{
        <<"command_type">> => <<"grant_license">>,
        <<"license_id">> => ?LICENSE_ID,
        <<"grant_reason">> => <<"free_offering">>
    }.

make_expire_payload() ->
    #{
        <<"command_type">> => <<"expire_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

make_renew_payload() ->
    #{
        <<"command_type">> => <<"renew_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

make_revoke_payload() ->
    #{
        <<"command_type">> => <<"revoke_license">>,
        <<"license_id">> => ?LICENSE_ID,
        <<"revoke_reason">> => <<"terms_violation">>
    }.

make_archive_payload() ->
    #{
        <<"command_type">> => <<"archive_license">>,
        <<"license_id">> => ?LICENSE_ID
    }.

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

%% Build state at a certain lifecycle point
state_initiated() ->
    {ok, S, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    S.

state_initiated_free() ->
    {ok, S, _} = execute_and_apply(fresh_state(), make_initiate_free_payload()),
    S.

state_accepted() ->
    {ok, S, _} = execute_and_apply(state_initiated(), make_accept_payload()),
    S.

state_accepted_free() ->
    {ok, S, _} = execute_and_apply(state_initiated_free(), make_accept_payload()),
    S.

state_bought() ->
    {ok, S, _} = execute_and_apply(state_accepted(), make_buy_payload()),
    S.

state_granted() ->
    {ok, S, _} = execute_and_apply(state_bought(), make_grant_payload()),
    S.

state_expired() ->
    {ok, S, _} = execute_and_apply(state_granted(), make_expire_payload()),
    S.

state_revoked() ->
    {ok, S, _} = execute_and_apply(state_granted(), make_revoke_payload()),
    S.

status(S) -> S#license_state.status.

%% ── Initial State Tests ────────────────────────────────────────────────────

initial_state_test() ->
    S = fresh_state(),
    ?assertEqual(0, status(S)),
    ?assertEqual(undefined, S#license_state.license_id).

%% ── Consumer Lifecycle Tests (Happy Path) ──────────────────────────────────

initiate_from_fresh_test() ->
    {ok, S, _} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_INITIATED)),
    ?assertEqual(?CONSUMER_ID, S#license_state.consumer_id),
    ?assertEqual(?PLUGIN_ID, S#license_state.plugin_id),
    ?assertEqual(?OFFERING_ID, S#license_state.offering_id),
    ?assertNotEqual(undefined, S#license_state.initiated_at).

initiate_carries_offering_snapshot_test() ->
    S = state_initiated(),
    ?assertEqual(<<"Trader">>, S#license_state.plugin_name),
    ?assertEqual(<<"Trading bot plugin">>, S#license_state.description),
    ?assertEqual(<<"trader.svg">>, S#license_state.icon),
    ?assertEqual(<<"Trading">>, S#license_state.group_name),
    ?assertEqual(<<"hecate-social/hecate-trader">>, S#license_state.github_repo),
    ?assertEqual(<<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>, S#license_state.oci_image),
    ?assertEqual(<<"author-1">>, S#license_state.author_id),
    ?assertEqual(<<"paid">>, S#license_state.license_type),
    ?assertEqual(999, S#license_state.fee_cents),
    ?assertEqual(<<"EUR">>, S#license_state.fee_currency),
    ?assertEqual(30, S#license_state.duration_days),
    ?assertEqual(3, S#license_state.node_limit).

accept_terms_test() ->
    {ok, S, _} = execute_and_apply(state_initiated(), make_accept_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_ACCEPTED)),
    %% Offering fields are already set from initiate — still there
    ?assertEqual(<<"Trader">>, S#license_state.plugin_name),
    ?assertEqual(<<"author-1">>, S#license_state.author_id),
    ?assertEqual(999, S#license_state.fee_cents),
    ?assertNotEqual(undefined, S#license_state.accepted_at).

buy_after_accept_test() ->
    {ok, S, _} = execute_and_apply(state_accepted(), make_buy_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_BOUGHT)),
    ?assertNotEqual(undefined, S#license_state.bought_at).

grant_after_buy_test() ->
    {ok, S, _} = execute_and_apply(state_bought(), make_grant_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_GRANTED)),
    ?assertNotEqual(undefined, S#license_state.granted_at).

expire_after_grant_test() ->
    {ok, S, _} = execute_and_apply(state_granted(), make_expire_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_EXPIRED)),
    ?assertNotEqual(undefined, S#license_state.expired_at).

renew_after_expire_test() ->
    {ok, S, _} = execute_and_apply(state_expired(), make_renew_payload()),
    %% Renewed = EXPIRED cleared, GRANTED set
    ?assert(evoq_bit_flags:has(status(S), ?LIC_GRANTED)),
    ?assert(evoq_bit_flags:has_not(status(S), ?LIC_EXPIRED)),
    ?assertNotEqual(undefined, S#license_state.renewed_at).

revoke_after_grant_test() ->
    {ok, S, _} = execute_and_apply(state_granted(), make_revoke_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_REVOKED)),
    ?assertNotEqual(undefined, S#license_state.revoked_at).

archive_after_revoke_test() ->
    {ok, S, _} = execute_and_apply(state_revoked(), make_archive_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_ARCHIVED)),
    ?assertNotEqual(undefined, S#license_state.archived_at).

%% ── Free Path ──────────────────────────────────────────────────────────────

grant_free_after_accept_test() ->
    %% Free path: initiate(free) -> accept -> grant directly (PM dispatches this)
    {ok, S, _} = execute_and_apply(state_accepted_free(), make_grant_payload()),
    ?assert(evoq_bit_flags:has(status(S), ?LIC_GRANTED)),
    ?assertEqual(0, S#license_state.fee_cents).

%% ── Terminal Paths ─────────────────────────────────────────────────────────

reject_terms_test() ->
    {ok, S, _} = execute_and_apply(state_initiated(), make_reject_payload()),
    %% Rejected sets ARCHIVED flag (terminal)
    ?assert(evoq_bit_flags:has(status(S), ?LIC_ARCHIVED)),
    ?assertNotEqual(undefined, S#license_state.rejected_at).

abandon_after_accept_test() ->
    {ok, S, _} = execute_and_apply(state_accepted(), make_abandon_payload()),
    %% Abandoned sets ARCHIVED flag (terminal)
    ?assert(evoq_bit_flags:has(status(S), ?LIC_ARCHIVED)),
    ?assertNotEqual(undefined, S#license_state.abandoned_at).

%% ── Business Rule Tests (invalid transitions) ─────────────────────────────

cannot_accept_from_fresh_test() ->
    Result = license_aggregate:execute(fresh_state(), make_accept_payload()),
    ?assertEqual({error, license_not_initiated}, Result).

cannot_buy_from_fresh_test() ->
    Result = license_aggregate:execute(fresh_state(), make_buy_payload()),
    ?assertEqual({error, license_not_initiated}, Result).

cannot_buy_from_initiated_test() ->
    Result = license_aggregate:execute(state_initiated(), make_buy_payload()),
    ?assertEqual({error, not_accepted}, Result).

cannot_grant_from_initiated_test() ->
    Result = license_aggregate:execute(state_initiated(), make_grant_payload()),
    ?assertEqual({error, not_accepted}, Result).

cannot_expire_from_accepted_test() ->
    Result = license_aggregate:execute(state_accepted(), make_expire_payload()),
    ?assertEqual({error, not_bought}, Result).

cannot_buy_after_grant_test() ->
    Result = license_aggregate:execute(state_granted(), make_buy_payload()),
    ?assertEqual({error, already_granted}, Result).

cannot_act_on_archived_test() ->
    {ok, Archived, _} = execute_and_apply(state_revoked(), make_archive_payload()),
    ?assertEqual({error, license_archived},
                 license_aggregate:execute(Archived, make_buy_payload())),
    ?assertEqual({error, license_archived},
                 license_aggregate:execute(Archived, make_grant_payload())).

revoked_only_allows_archive_test() ->
    S = state_revoked(),
    ?assertEqual({error, license_revoked},
                 license_aggregate:execute(S, make_buy_payload())),
    ?assertEqual({error, license_revoked},
                 license_aggregate:execute(S, make_grant_payload())),
    %% Archive should work
    {ok, _, _} = execute_and_apply(S, make_archive_payload()).

expired_allows_renew_or_archive_test() ->
    S = state_expired(),
    ?assertEqual({error, license_expired},
                 license_aggregate:execute(S, make_buy_payload())),
    %% Renew and archive should work
    {ok, _, _} = execute_and_apply(S, make_renew_payload()),
    {ok, _, _} = execute_and_apply(S, make_archive_payload()).

%% ── Event Content Tests ────────────────────────────────────────────────────

initiate_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(fresh_state(), make_initiate_payload()),
    ?assertEqual(<<"license_initiated_v1">>, maps:get(event_type, Event)).

accept_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_initiated(), make_accept_payload()),
    ?assertEqual(<<"offering_terms_accepted_v1">>, maps:get(event_type, Event)).

reject_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_initiated(), make_reject_payload()),
    ?assertEqual(<<"offering_terms_rejected_v1">>, maps:get(event_type, Event)).

buy_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_accepted(), make_buy_payload()),
    ?assertEqual(<<"license_bought_v1">>, maps:get(event_type, Event)).

grant_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_bought(), make_grant_payload()),
    ?assertEqual(<<"license_granted_v1">>, maps:get(event_type, Event)).

expire_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_granted(), make_expire_payload()),
    ?assertEqual(<<"license_expired_v1">>, maps:get(event_type, Event)).

renew_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_expired(), make_renew_payload()),
    ?assertEqual(<<"license_renewed_v1">>, maps:get(event_type, Event)).

revoke_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_granted(), make_revoke_payload()),
    ?assertEqual(<<"license_revoked_v1">>, maps:get(event_type, Event)).

archive_event_type_test() ->
    {ok, _, [Event]} = execute_and_apply(state_revoked(), make_archive_payload()),
    ?assertEqual(<<"license_archived_v1">>, maps:get(event_type, Event)).

%% ── Bit Flag Tests ─────────────────────────────────────────────────────────

flag_map_test() ->
    Map = license_aggregate:flag_map(),
    ?assertEqual(<<"Initiated">>, maps:get(1, Map)),
    ?assertEqual(<<"Accepted">>,  maps:get(2, Map)),
    ?assertEqual(<<"Bought">>,    maps:get(4, Map)),
    ?assertEqual(<<"Granted">>,   maps:get(8, Map)),
    ?assertEqual(<<"Expired">>,   maps:get(16, Map)),
    ?assertEqual(<<"Revoked">>,   maps:get(32, Map)),
    ?assertEqual(<<"Archived">>,  maps:get(64, Map)).

full_paid_lifecycle_flags_test() ->
    S1 = state_initiated(),
    ?assertEqual(?LIC_INITIATED, status(S1)),

    {ok, S2, _} = execute_and_apply(S1, make_accept_payload()),
    ?assert(evoq_bit_flags:has_all(status(S2), [?LIC_INITIATED, ?LIC_ACCEPTED])),

    {ok, S3, _} = execute_and_apply(S2, make_buy_payload()),
    ?assert(evoq_bit_flags:has_all(status(S3), [?LIC_INITIATED, ?LIC_ACCEPTED, ?LIC_BOUGHT])),

    {ok, S4, _} = execute_and_apply(S3, make_grant_payload()),
    ?assert(evoq_bit_flags:has_all(status(S4), [?LIC_INITIATED, ?LIC_ACCEPTED, ?LIC_BOUGHT, ?LIC_GRANTED])).

%% ── Accept Event Carries fee_cents from State ────────────────────────────

accept_event_echoes_fee_cents_test() ->
    %% Paid offering
    {ok, _, [Event]} = execute_and_apply(state_initiated(), make_accept_payload()),
    ?assertEqual(999, maps:get(fee_cents, Event)),
    %% Free offering
    {ok, _, [FreeEvent]} = execute_and_apply(state_initiated_free(), make_accept_payload()),
    ?assertEqual(0, maps:get(fee_cents, FreeEvent)).
