%%% @doc Tests for learning_aggregate: execute/2 (command routing) and apply/2 (state transitions).
%%%
%%% Pure function tests — no external dependencies (no ReckonDB, no mesh).
%%% Tests the full learning lifecycle: submit -> validate -> endorse/dispute -> resolve.
-module(learning_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

%% Copied from learning_aggregate.erl for test-side record access.
-record(learning_state, {
    learning_id    :: binary() | undefined,
    submitter_id   :: binary() | undefined,
    category       :: binary() | undefined,
    domain         :: binary() | undefined,
    tags           :: [binary()],
    title          :: binary() | undefined,
    description    :: binary() | undefined,
    bad_example    :: binary() | undefined,
    good_example   :: binary() | undefined,
    context        :: binary() | undefined,
    severity       :: binary() | undefined,
    confidence     :: float(),
    source         :: binary() | undefined,
    status         :: non_neg_integer(),
    validator_id   :: binary() | undefined,
    endorser_ids   :: [binary()],
    disputer_ids   :: [binary()],
    submitted_at   :: non_neg_integer() | undefined,
    validated_at   :: non_neg_integer() | undefined
}).

%% Bit flags (must match learning_aggregate.erl)
-define(SUBMITTED,  1).
-define(VALIDATED,  2).
-define(REJECTED,   4).
-define(ENDORSED,   8).
-define(DISPUTED,  16).
-define(RESOLVED,  32).

%% ===================================================================
%% Test generators
%% ===================================================================

initial_state_test_() ->
    [
        {"initial state has status=0 and empty lists", fun initial_state/0}
    ].

execute_test_() ->
    [
        {"submit_learning happy path",                      fun execute_submit_happy/0},
        {"submit_learning already exists",                  fun execute_submit_already_exists/0},
        {"validate_learning happy path",                    fun execute_validate_happy/0},
        {"validate_learning on non-submitted state",        fun execute_validate_not_submitted/0},
        {"validate_learning already validated",             fun execute_validate_already_validated/0},
        {"reject_learning happy path",                      fun execute_reject_happy/0},
        {"reject_learning already validated",               fun execute_reject_already_validated/0},
        {"endorse_learning happy path",                     fun execute_endorse_happy/0},
        {"endorse_learning not validated",                  fun execute_endorse_not_validated/0},
        {"endorse_learning double endorse",                 fun execute_endorse_double/0},
        {"dispute_learning happy path",                     fun execute_dispute_happy/0},
        {"dispute_learning double dispute",                 fun execute_dispute_double/0},
        {"resolve_learning_dispute happy path",             fun execute_resolve_happy/0},
        {"resolve_learning_dispute not disputed",           fun execute_resolve_not_disputed/0},
        {"resolve_learning_dispute already resolved",       fun execute_resolve_already_resolved/0}
    ].

apply_event_test_() ->
    [
        {"learning_submitted_v1 sets fields and SUBMITTED flag",  fun apply_submitted/0},
        {"learning_validated_v1 adds VALIDATED flag",             fun apply_validated/0},
        {"learning_rejected_v1 adds REJECTED flag",               fun apply_rejected/0},
        {"learning_endorsed_v1 adds ENDORSED flag and endorser",  fun apply_endorsed/0},
        {"learning_disputed_v1 adds DISPUTED flag and disputer",  fun apply_disputed/0},
        {"learning_dispute_resolved_v1 adds RESOLVED flag",       fun apply_resolved/0}
    ].

lifecycle_test_() ->
    [
        {"full lifecycle: submit -> validate -> endorse -> dispute -> resolve",
         fun full_lifecycle/0}
    ].

%% ===================================================================
%% Helpers
%% ===================================================================

fresh() -> learning_aggregate:initial_state().

submit_payload() ->
    #{command_type => <<"submit_learning">>,
      learning_id => <<"lrn-1">>,
      submitter_id => <<"agent-1">>,
      category => <<"pattern">>,
      domain => <<"erlang">>,
      tags => [<<"otp">>, <<"testing">>],
      title => <<"Test learning">>,
      description => <<"A test learning description">>,
      bad_example => <<"bad code here">>,
      good_example => <<"good code here">>,
      context => <<"unit testing">>,
      severity => <<"suggestion">>,
      confidence => 0.8,
      source => <<"discovered">>}.

validate_payload() ->
    #{command_type => <<"validate_learning">>,
      learning_id => <<"lrn-1">>,
      validator_id => <<"validator-1">>}.

reject_payload() ->
    #{command_type => <<"reject_learning">>,
      learning_id => <<"lrn-1">>,
      validator_id => <<"validator-1">>,
      reason => <<"Not applicable">>}.

endorse_payload() ->
    #{command_type => <<"endorse_learning">>,
      learning_id => <<"lrn-1">>,
      agent_id => <<"endorser-1">>}.

dispute_payload() ->
    #{command_type => <<"dispute_learning">>,
      learning_id => <<"lrn-1">>,
      agent_id => <<"disputer-1">>,
      reason => <<"Disagree with approach">>}.

resolve_payload() ->
    #{command_type => <<"resolve_learning_dispute">>,
      learning_id => <<"lrn-1">>,
      resolver_id => <<"resolver-1">>,
      resolution => <<"Resolved via discussion">>}.

%% Build a submitted state by executing submit and applying the event.
submitted_state() ->
    S0 = fresh(),
    {ok, [Event]} = learning_aggregate:execute(S0, submit_payload()),
    learning_aggregate:apply(S0, Event).

%% Build a validated state (submitted + validated).
validated_state() ->
    S1 = submitted_state(),
    {ok, [Event]} = learning_aggregate:execute(S1, validate_payload()),
    learning_aggregate:apply(S1, Event).

%% Build a disputed state (submitted + validated + disputed).
disputed_state() ->
    S2 = validated_state(),
    {ok, [Event]} = learning_aggregate:execute(S2, dispute_payload()),
    learning_aggregate:apply(S2, Event).

%% ===================================================================
%% Initial state tests
%% ===================================================================

initial_state() ->
    S = fresh(),
    ?assertEqual(0, S#learning_state.status),
    ?assertEqual(undefined, S#learning_state.learning_id),
    ?assertEqual([], S#learning_state.endorser_ids),
    ?assertEqual([], S#learning_state.disputer_ids),
    ?assertEqual([], S#learning_state.tags),
    ?assertEqual(undefined, S#learning_state.submitter_id),
    ?assertEqual(undefined, S#learning_state.validator_id),
    ?assertEqual(0.5, S#learning_state.confidence).

%% ===================================================================
%% Execute tests
%% ===================================================================

execute_submit_happy() ->
    {ok, [Event]} = learning_aggregate:execute(fresh(), submit_payload()),
    ?assertEqual(<<"learning_submitted_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lrn-1">>, maps:get(learning_id, Event)),
    ?assertEqual(<<"agent-1">>, maps:get(submitter_id, Event)),
    ?assertEqual(<<"pattern">>, maps:get(category, Event)),
    ?assertEqual(<<"erlang">>, maps:get(domain, Event)),
    ?assertEqual(<<"Test learning">>, maps:get(title, Event)),
    ?assertEqual(<<"suggestion">>, maps:get(severity, Event)),
    ?assert(is_number(maps:get(submitted_at, Event))).

execute_submit_already_exists() ->
    S1 = submitted_state(),
    ?assertEqual({error, learning_already_exists},
                 learning_aggregate:execute(S1, submit_payload())).

execute_validate_happy() ->
    S1 = submitted_state(),
    {ok, [Event]} = learning_aggregate:execute(S1, validate_payload()),
    ?assertEqual(<<"learning_validated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lrn-1">>, maps:get(learning_id, Event)),
    ?assertEqual(<<"validator-1">>, maps:get(validator_id, Event)),
    ?assert(is_number(maps:get(validated_at, Event))).

execute_validate_not_submitted() ->
    ?assertEqual({error, learning_not_found},
                 learning_aggregate:execute(fresh(), validate_payload())).

execute_validate_already_validated() ->
    S2 = validated_state(),
    ?assertEqual({error, learning_not_pending},
                 learning_aggregate:execute(S2, validate_payload())).

execute_reject_happy() ->
    S1 = submitted_state(),
    {ok, [Event]} = learning_aggregate:execute(S1, reject_payload()),
    ?assertEqual(<<"learning_rejected_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lrn-1">>, maps:get(learning_id, Event)),
    ?assertEqual(<<"validator-1">>, maps:get(validator_id, Event)).

execute_reject_already_validated() ->
    S2 = validated_state(),
    ?assertEqual({error, learning_not_pending},
                 learning_aggregate:execute(S2, reject_payload())).

execute_endorse_happy() ->
    S2 = validated_state(),
    {ok, [Event]} = learning_aggregate:execute(S2, endorse_payload()),
    ?assertEqual(<<"learning_endorsed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lrn-1">>, maps:get(learning_id, Event)),
    ?assertEqual(<<"endorser-1">>, maps:get(agent_id, Event)).

execute_endorse_not_validated() ->
    S1 = submitted_state(),
    ?assertEqual({error, learning_not_validated},
                 learning_aggregate:execute(S1, endorse_payload())).

execute_endorse_double() ->
    S2 = validated_state(),
    {ok, [Event]} = learning_aggregate:execute(S2, endorse_payload()),
    S3 = learning_aggregate:apply(S2, Event),
    %% Same agent_id tries to endorse again
    ?assertEqual({error, already_endorsed},
                 learning_aggregate:execute(S3, endorse_payload())).

execute_dispute_happy() ->
    S2 = validated_state(),
    {ok, [Event]} = learning_aggregate:execute(S2, dispute_payload()),
    ?assertEqual(<<"learning_disputed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lrn-1">>, maps:get(learning_id, Event)),
    ?assertEqual(<<"disputer-1">>, maps:get(agent_id, Event)).

execute_dispute_double() ->
    S2 = validated_state(),
    {ok, [Event]} = learning_aggregate:execute(S2, dispute_payload()),
    S3 = learning_aggregate:apply(S2, Event),
    %% Same agent_id tries to dispute again
    ?assertEqual({error, already_disputed},
                 learning_aggregate:execute(S3, dispute_payload())).

execute_resolve_happy() ->
    S3 = disputed_state(),
    {ok, [Event]} = learning_aggregate:execute(S3, resolve_payload()),
    ?assertEqual(<<"learning_dispute_resolved_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"lrn-1">>, maps:get(learning_id, Event)),
    ?assertEqual(<<"resolver-1">>, maps:get(resolver_id, Event)).

execute_resolve_not_disputed() ->
    S2 = validated_state(),
    ?assertEqual({error, learning_not_disputed},
                 learning_aggregate:execute(S2, resolve_payload())).

execute_resolve_already_resolved() ->
    S3 = disputed_state(),
    {ok, [Event]} = learning_aggregate:execute(S3, resolve_payload()),
    S4 = learning_aggregate:apply(S3, Event),
    ?assertEqual({error, learning_not_disputed},
                 learning_aggregate:execute(S4, resolve_payload())).

%% ===================================================================
%% Apply event tests
%% ===================================================================

apply_submitted() ->
    S0 = fresh(),
    Event = #{
        event_type => <<"learning_submitted_v1">>,
        learning_id => <<"lrn-1">>,
        submitter_id => <<"agent-1">>,
        category => <<"pattern">>,
        domain => <<"erlang">>,
        tags => [<<"otp">>],
        title => <<"Test learning">>,
        description => <<"desc">>,
        bad_example => <<"bad">>,
        good_example => <<"good">>,
        context => <<"ctx">>,
        severity => <<"suggestion">>,
        confidence => 0.8,
        source => <<"discovered">>,
        submitted_at => 1000
    },
    S1 = learning_aggregate:apply(S0, Event),
    ?assertEqual(<<"lrn-1">>, S1#learning_state.learning_id),
    ?assertEqual(<<"agent-1">>, S1#learning_state.submitter_id),
    ?assertEqual(<<"pattern">>, S1#learning_state.category),
    ?assertEqual(<<"erlang">>, S1#learning_state.domain),
    ?assertEqual([<<"otp">>], S1#learning_state.tags),
    ?assertEqual(<<"Test learning">>, S1#learning_state.title),
    ?assertEqual(<<"desc">>, S1#learning_state.description),
    ?assertEqual(<<"bad">>, S1#learning_state.bad_example),
    ?assertEqual(<<"good">>, S1#learning_state.good_example),
    ?assertEqual(<<"ctx">>, S1#learning_state.context),
    ?assertEqual(<<"suggestion">>, S1#learning_state.severity),
    ?assertEqual(0.8, S1#learning_state.confidence),
    ?assertEqual(<<"discovered">>, S1#learning_state.source),
    ?assertEqual(1000, S1#learning_state.submitted_at),
    ?assertEqual(?SUBMITTED, S1#learning_state.status).

apply_validated() ->
    S1 = submitted_state(),
    Event = #{
        event_type => <<"learning_validated_v1">>,
        learning_id => <<"lrn-1">>,
        validator_id => <<"validator-1">>,
        validated_at => 2000
    },
    S2 = learning_aggregate:apply(S1, Event),
    ?assertEqual(<<"validator-1">>, S2#learning_state.validator_id),
    ?assertEqual(2000, S2#learning_state.validated_at),
    ?assert((S2#learning_state.status band ?SUBMITTED) =/= 0),
    ?assert((S2#learning_state.status band ?VALIDATED) =/= 0).

apply_rejected() ->
    S1 = submitted_state(),
    Event = #{
        event_type => <<"learning_rejected_v1">>,
        learning_id => <<"lrn-1">>,
        validator_id => <<"validator-1">>
    },
    S2 = learning_aggregate:apply(S1, Event),
    ?assertEqual(<<"validator-1">>, S2#learning_state.validator_id),
    ?assert((S2#learning_state.status band ?SUBMITTED) =/= 0),
    ?assert((S2#learning_state.status band ?REJECTED) =/= 0).

apply_endorsed() ->
    S2 = validated_state(),
    Event = #{
        event_type => <<"learning_endorsed_v1">>,
        learning_id => <<"lrn-1">>,
        agent_id => <<"endorser-1">>,
        endorsed_at => 3000
    },
    S3 = learning_aggregate:apply(S2, Event),
    ?assert((S3#learning_state.status band ?ENDORSED) =/= 0),
    ?assert(lists:member(<<"endorser-1">>, S3#learning_state.endorser_ids)).

apply_disputed() ->
    S2 = validated_state(),
    Event = #{
        event_type => <<"learning_disputed_v1">>,
        learning_id => <<"lrn-1">>,
        agent_id => <<"disputer-1">>,
        reason => <<"bad approach">>,
        disputed_at => 3000
    },
    S3 = learning_aggregate:apply(S2, Event),
    ?assert((S3#learning_state.status band ?DISPUTED) =/= 0),
    ?assert(lists:member(<<"disputer-1">>, S3#learning_state.disputer_ids)).

apply_resolved() ->
    S3 = disputed_state(),
    Event = #{
        event_type => <<"learning_dispute_resolved_v1">>,
        learning_id => <<"lrn-1">>,
        resolver_id => <<"resolver-1">>,
        resolution => <<"Fixed">>,
        resolved_at => 4000
    },
    S4 = learning_aggregate:apply(S3, Event),
    ?assert((S4#learning_state.status band ?RESOLVED) =/= 0).

%% ===================================================================
%% Full lifecycle test
%% ===================================================================

full_lifecycle() ->
    S0 = fresh(),

    %% Step 1: Submit
    {ok, [SubmitEvt]} = learning_aggregate:execute(S0, submit_payload()),
    ?assertEqual(<<"learning_submitted_v1">>, maps:get(event_type, SubmitEvt)),
    S1 = learning_aggregate:apply(S0, SubmitEvt),
    ?assertEqual(?SUBMITTED, S1#learning_state.status),
    ?assertEqual(<<"lrn-1">>, S1#learning_state.learning_id),

    %% Step 2: Validate
    {ok, [ValidateEvt]} = learning_aggregate:execute(S1, validate_payload()),
    ?assertEqual(<<"learning_validated_v1">>, maps:get(event_type, ValidateEvt)),
    S2 = learning_aggregate:apply(S1, ValidateEvt),
    ?assert((S2#learning_state.status band ?SUBMITTED) =/= 0),
    ?assert((S2#learning_state.status band ?VALIDATED) =/= 0),
    ?assertEqual(<<"validator-1">>, S2#learning_state.validator_id),

    %% Step 3: Endorse
    {ok, [EndorseEvt]} = learning_aggregate:execute(S2, endorse_payload()),
    ?assertEqual(<<"learning_endorsed_v1">>, maps:get(event_type, EndorseEvt)),
    S3 = learning_aggregate:apply(S2, EndorseEvt),
    ?assert((S3#learning_state.status band ?ENDORSED) =/= 0),
    ?assertEqual([<<"endorser-1">>], S3#learning_state.endorser_ids),

    %% Step 4: Dispute
    {ok, [DisputeEvt]} = learning_aggregate:execute(S3, dispute_payload()),
    ?assertEqual(<<"learning_disputed_v1">>, maps:get(event_type, DisputeEvt)),
    S4 = learning_aggregate:apply(S3, DisputeEvt),
    ?assert((S4#learning_state.status band ?DISPUTED) =/= 0),
    ?assertEqual([<<"disputer-1">>], S4#learning_state.disputer_ids),

    %% Step 5: Resolve
    {ok, [ResolveEvt]} = learning_aggregate:execute(S4, resolve_payload()),
    ?assertEqual(<<"learning_dispute_resolved_v1">>, maps:get(event_type, ResolveEvt)),
    S5 = learning_aggregate:apply(S4, ResolveEvt),
    ?assert((S5#learning_state.status band ?RESOLVED) =/= 0),

    %% Verify final state has all flags accumulated
    FinalStatus = S5#learning_state.status,
    ?assert((FinalStatus band ?SUBMITTED) =/= 0),
    ?assert((FinalStatus band ?VALIDATED) =/= 0),
    ?assert((FinalStatus band ?ENDORSED) =/= 0),
    ?assert((FinalStatus band ?DISPUTED) =/= 0),
    ?assert((FinalStatus band ?RESOLVED) =/= 0),
    %% Should NOT have rejected
    ?assertEqual(0, FinalStatus band ?REJECTED).
