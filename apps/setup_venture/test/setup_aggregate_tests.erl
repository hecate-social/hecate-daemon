%%% @doc Layer 1: Dossier Tests — Pure aggregate state reconstruction.
%%% Tests apply_event/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since setup_state record is internal to setup_aggregate, we verify
%%% state correctness through execute/2 behavior (state machine guards)
%%% and through the behaviour callback apply/2.
-module(setup_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("setup_venture/include/venture_status.hrl").

%% Record field positions in setup_state (record tag is element 1)
-define(F_VENTURE_ID,   2).
-define(F_NAME,         3).
-define(F_BRIEF,        4).
-define(F_STATUS,       5).
-define(F_REPOS,        6).
-define(F_SKILLS,       7).
-define(F_CONTEXT_MAP,  8).
-define(F_INITIATED_AT, 9).
-define(F_INITIATED_BY, 10).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

setup_event() ->
    #{<<"event_type">> => <<"venture_setup_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"name">> => <<"Test Venture">>,
      <<"brief">> => <<"A test venture">>,
      <<"repos">> => [<<"repo1">>, <<"repo2">>],
      <<"skills">> => [<<"erlang">>, <<"otp">>],
      <<"context_map">> => #{<<"key">> => <<"value">>},
      <<"initiated_at">> => 1000,
      <<"initiated_by">> => <<"test@host">>}.

refine_event() ->
    #{<<"event_type">> => <<"venture_vision_refined_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"brief">> => <<"Updated brief">>,
      <<"repos">> => [<<"repo1">>, <<"repo2">>, <<"repo3">>],
      <<"skills">> => [<<"erlang">>, <<"otp">>, <<"rust">>],
      <<"context_map">> => #{<<"key">> => <<"updated">>},
      <<"refined_by">> => <<"test@host">>,
      <<"refined_at">> => 2000}.

submit_event() ->
    #{<<"event_type">> => <<"venture_vision_submitted_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"submitted_by">> => <<"test@host">>,
      <<"submitted_at">> => 3000}.

archive_event() ->
    #{<<"event_type">> => <<"venture_archived_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"archived_by">> => <<"test@host">>,
      <<"reason">> => <<"test cleanup">>,
      <<"archived_at">> => 4000}.

setup_cmd() ->
    #{<<"command_type">> => <<"setup_venture">>,
      <<"name">> => <<"Test">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"initiated_by">> => <<"test@host">>}.

refine_cmd() ->
    #{<<"command_type">> => <<"refine_vision">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"brief">> => <<"New brief">>}.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% initial_state/0 returns zeroed state
initial_state_test() ->
    S = setup_aggregate:initial_state(),
    ?assertEqual(undefined, element(?F_VENTURE_ID, S)),
    ?assertEqual(undefined, element(?F_NAME, S)),
    ?assertEqual(undefined, element(?F_BRIEF, S)),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual([], element(?F_REPOS, S)),
    ?assertEqual([], element(?F_SKILLS, S)),
    ?assertEqual(#{}, element(?F_CONTEXT_MAP, S)),
    ?assertEqual(undefined, element(?F_INITIATED_AT, S)),
    ?assertEqual(undefined, element(?F_INITIATED_BY, S)).

%% init/1 callback returns {ok, initial_state}
init_callback_test() ->
    {ok, S} = setup_aggregate:init(<<"any-id">>),
    ?assertEqual(0, element(?F_STATUS, S)).

%% Apply venture_setup_v1 event populates all fields
apply_setup_event_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    ?assertEqual(?VENTURE_SETUP, element(?F_STATUS, S1) band ?VENTURE_SETUP),
    ?assertEqual(<<"vent-1">>, element(?F_VENTURE_ID, S1)),
    ?assertEqual(<<"Test Venture">>, element(?F_NAME, S1)),
    ?assertEqual(<<"A test venture">>, element(?F_BRIEF, S1)),
    ?assertEqual([<<"repo1">>, <<"repo2">>], element(?F_REPOS, S1)),
    ?assertEqual([<<"erlang">>, <<"otp">>], element(?F_SKILLS, S1)),
    ?assertEqual(#{<<"key">> => <<"value">>}, element(?F_CONTEXT_MAP, S1)),
    ?assertEqual(1000, element(?F_INITIATED_AT, S1)),
    ?assertEqual(<<"test@host">>, element(?F_INITIATED_BY, S1)).

%% Apply refine event updates vision fields + sets REFINED bit
apply_refine_event_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    S2 = setup_aggregate:apply_event(refine_event(), S1),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?VENTURE_SETUP),
    ?assertNotEqual(0, Status band ?VENTURE_VISION_REFINED),
    ?assertEqual(<<"Updated brief">>, element(?F_BRIEF, S2)),
    ?assertEqual([<<"repo1">>, <<"repo2">>, <<"repo3">>], element(?F_REPOS, S2)),
    ?assertEqual([<<"erlang">>, <<"otp">>, <<"rust">>], element(?F_SKILLS, S2)),
    ?assertEqual(#{<<"key">> => <<"updated">>}, element(?F_CONTEXT_MAP, S2)).

%% Refine with partial fields — only brief changes, others untouched
apply_refine_partial_event_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    PartialRefine = #{<<"event_type">> => <<"venture_vision_refined_v1">>,
                      <<"venture_id">> => <<"vent-1">>,
                      <<"brief">> => <<"Only brief changed">>,
                      <<"refined_at">> => 2000},
    S2 = setup_aggregate:apply_event(PartialRefine, S1),
    ?assertEqual(<<"Only brief changed">>, element(?F_BRIEF, S2)),
    ?assertEqual([<<"repo1">>, <<"repo2">>], element(?F_REPOS, S2)),
    ?assertEqual([<<"erlang">>, <<"otp">>], element(?F_SKILLS, S2)),
    ?assertEqual(#{<<"key">> => <<"value">>}, element(?F_CONTEXT_MAP, S2)).

%% Apply submit event sets SUBMITTED bit
apply_submit_event_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    S2 = setup_aggregate:apply_event(submit_event(), S1),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?VENTURE_SUBMITTED),
    ?assertNotEqual(0, Status band ?VENTURE_SETUP).

%% Apply archive event sets ARCHIVED bit
apply_archive_event_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    S2 = setup_aggregate:apply_event(archive_event(), S1),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?VENTURE_ARCHIVED),
    ?assertNotEqual(0, Status band ?VENTURE_SETUP).

%% Full lifecycle: setup -> refine -> submit -> archive = all 4 bits set (15)
full_lifecycle_state_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    S2 = setup_aggregate:apply_event(refine_event(), S1),
    S3 = setup_aggregate:apply_event(submit_event(), S2),
    S4 = setup_aggregate:apply_event(archive_event(), S3),
    ?assertEqual(15, element(?F_STATUS, S4)),
    ?assertEqual(<<"vent-1">>, element(?F_VENTURE_ID, S4)),
    ?assertEqual(<<"Updated brief">>, element(?F_BRIEF, S4)).

%% Unknown event leaves state unchanged
apply_unknown_event_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    Unknown = #{<<"event_type">> => <<"some_random_event">>, <<"data">> => <<"whatever">>},
    S2 = setup_aggregate:apply_event(Unknown, S1),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
apply_with_atom_keys_test() ->
    S0 = setup_aggregate:initial_state(),
    AtomEvent = #{event_type => <<"venture_setup_v1">>,
                  venture_id => <<"vent-atom">>,
                  name => <<"Atom Venture">>,
                  brief => <<"Atom brief">>,
                  repos => [],
                  skills => [],
                  context_map => #{},
                  initiated_at => 5000,
                  initiated_by => <<"atom@host">>},
    S1 = setup_aggregate:apply_event(AtomEvent, S0),
    ?assertEqual(<<"vent-atom">>, element(?F_VENTURE_ID, S1)),
    ?assertEqual(<<"Atom Venture">>, element(?F_NAME, S1)),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?VENTURE_SETUP).

%% flag_map/0 returns expected labels
flag_map_test() ->
    Map = setup_aggregate:flag_map(),
    ?assertEqual(<<"New">>, maps:get(0, Map)),
    ?assertEqual(<<"Setup">>, maps:get(?VENTURE_SETUP, Map)),
    ?assertEqual(<<"Vision Refined">>, maps:get(?VENTURE_VISION_REFINED, Map)),
    ?assertEqual(<<"Submitted">>, maps:get(?VENTURE_SUBMITTED, Map)),
    ?assertEqual(<<"Archived">>, maps:get(?VENTURE_ARCHIVED, Map)).

%% Behaviour callback: apply/2 takes (State, Event) — state first
apply_callback_order_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply(S0, setup_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?VENTURE_SETUP),
    ?assertEqual(<<"vent-1">>, element(?F_VENTURE_ID, S1)).

%% State reconstruction via execute/2 validates state machine behavior:
%% Fresh state allows setup, rejects refine
state_machine_via_execute_test() ->
    S0 = setup_aggregate:initial_state(),
    %% Fresh state: setup should succeed
    {ok, _Events} = setup_aggregate:execute(S0, setup_cmd()),
    %% Fresh state: refine should fail (not setup yet)
    ?assertEqual({error, venture_not_found},
                 setup_aggregate:execute(S0, refine_cmd())).

%% After applying setup event, execute rejects duplicate setup
state_machine_after_setup_test() ->
    S0 = setup_aggregate:initial_state(),
    S1 = setup_aggregate:apply_event(setup_event(), S0),
    %% Already setup: duplicate setup should fail
    ?assertEqual({error, venture_already_setup},
                 setup_aggregate:execute(S1, setup_cmd())),
    %% Setup state: refine should succeed
    {ok, _Events} = setup_aggregate:execute(S1, refine_cmd()).
