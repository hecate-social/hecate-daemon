%%% @doc Tests for learning projections (event -> SQLite learnings table).
%%%
%%% Uses a temp SQLite database via query_mentorships_store.
%%% Each test group gets a fresh database (foreach pattern).
-module(learnings_projection_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"learning_submitted projects into learnings with status=1",
                fun proj_submitted/0},
            {"learning_validated sets VALIDATED bit and validator_id",
                fun proj_validated/0},
            {"learning_rejected sets REJECTED bit",
                fun proj_rejected/0},
            {"learning_endorsed sets ENDORSED bit and increments endorsement_count",
                fun proj_endorsed/0},
            {"two endorsements increment endorsement_count to 2",
                fun proj_endorsed_twice/0},
            {"learning_disputed sets DISPUTED bit and increments dispute_count",
                fun proj_disputed/0},
            {"learning_dispute_resolved sets RESOLVED bit",
                fun proj_resolved/0},
            {"roundtrip: project then get_learning_by_id",
                fun roundtrip_by_id/0},
            {"roundtrip: project 2 learnings then get_learnings_page",
                fun roundtrip_page/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    file:delete(shared_paths:sqlite_path("query_mentorships.db")),
    file:delete(shared_paths:sqlite_path("query_mentorships.db-wal")),
    file:delete(shared_paths:sqlite_path("query_mentorships.db-shm")),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_mentorships_store:start_link(),
    query_mentorships_store:init_schema(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    file:delete(shared_paths:sqlite_path("query_mentorships.db")),
    file:delete(shared_paths:sqlite_path("query_mentorships.db-wal")),
    file:delete(shared_paths:sqlite_path("query_mentorships.db-shm")),
    ok.

%% ===================================================================
%% Helpers
%% ===================================================================

submit_event(Id) ->
    #{
        learning_id => Id,
        submitter_id => <<"agent-001">>,
        category => <<"antipattern">>,
        domain => <<"erlang">>,
        tags => [<<"otp">>, <<"gen_server">>],
        title => <<"Avoid blocking gen_server calls">>,
        description => <<"Long calls block the mailbox">>,
        bad_example => <<"gen_server:call(Pid, heavy_work)">>,
        good_example => <<"gen_server:cast(Pid, {work, self()})">>,
        context => <<"production systems">>,
        severity => <<"warning">>,
        confidence => 0.9,
        source => <<"code_review">>,
        submitted_at => 1000
    }.

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_submitted() ->
    Event = submit_event(<<"learn-001">>),
    ok = learning_submitted_v1_to_learnings:project(Event),
    {ok, Rows} = query_mentorships_store:query(
        "SELECT id, submitter_id, category, domain, title, status, "
        "endorsement_count, dispute_count FROM learnings", []),
    ?assertEqual(1, length(Rows)),
    [[Id, Sub, Cat, Dom, Title, Status, EndCnt, DispCnt]] = Rows,
    ?assertEqual(<<"learn-001">>, Id),
    ?assertEqual(<<"agent-001">>, Sub),
    ?assertEqual(<<"antipattern">>, Cat),
    ?assertEqual(<<"erlang">>, Dom),
    ?assertEqual(<<"Avoid blocking gen_server calls">>, Title),
    ?assertEqual(1, Status),
    ?assertEqual(0, EndCnt),
    ?assertEqual(0, DispCnt).

proj_validated() ->
    ok = learning_submitted_v1_to_learnings:project(submit_event(<<"learn-002">>)),
    ValidateEvent = #{
        learning_id => <<"learn-002">>,
        validator_id => <<"validator-001">>,
        validated_at => 2000
    },
    ok = learning_validated_v1_to_learnings:project(ValidateEvent),
    {ok, [[Status, ValidatorId, ValidatedAt]]} =
        query_mentorships_store:query(
            "SELECT status, validator_id, validated_at FROM learnings WHERE id = ?1",
            [<<"learn-002">>]),
    %% SUBMITTED=1 | VALIDATED=2 = 3
    ?assert(Status band 2 =/= 0),
    ?assertEqual(<<"validator-001">>, ValidatorId),
    ?assertEqual(2000, ValidatedAt).

proj_rejected() ->
    ok = learning_submitted_v1_to_learnings:project(submit_event(<<"learn-003">>)),
    RejectEvent = #{
        learning_id => <<"learn-003">>,
        validator_id => <<"validator-002">>
    },
    ok = learning_rejected_v1_to_learnings:project(RejectEvent),
    {ok, [[Status, ValidatorId]]} =
        query_mentorships_store:query(
            "SELECT status, validator_id FROM learnings WHERE id = ?1",
            [<<"learn-003">>]),
    %% SUBMITTED=1 | REJECTED=4 = 5
    ?assert(Status band 4 =/= 0),
    ?assertEqual(<<"validator-002">>, ValidatorId).

proj_endorsed() ->
    ok = learning_submitted_v1_to_learnings:project(submit_event(<<"learn-004">>)),
    ok = learning_validated_v1_to_learnings:project(#{
        learning_id => <<"learn-004">>,
        validator_id => <<"validator-001">>,
        validated_at => 2000
    }),
    ok = learning_endorsed_v1_to_learnings:project(#{
        learning_id => <<"learn-004">>
    }),
    {ok, [[Status, EndCnt]]} =
        query_mentorships_store:query(
            "SELECT status, endorsement_count FROM learnings WHERE id = ?1",
            [<<"learn-004">>]),
    %% ENDORSED bit = 8
    ?assert(Status band 8 =/= 0),
    ?assertEqual(1, EndCnt).

proj_endorsed_twice() ->
    ok = learning_submitted_v1_to_learnings:project(submit_event(<<"learn-005">>)),
    ok = learning_validated_v1_to_learnings:project(#{
        learning_id => <<"learn-005">>,
        validator_id => <<"v-001">>,
        validated_at => 2000
    }),
    ok = learning_endorsed_v1_to_learnings:project(#{learning_id => <<"learn-005">>}),
    ok = learning_endorsed_v1_to_learnings:project(#{learning_id => <<"learn-005">>}),
    {ok, [[EndCnt]]} =
        query_mentorships_store:query(
            "SELECT endorsement_count FROM learnings WHERE id = ?1",
            [<<"learn-005">>]),
    ?assertEqual(2, EndCnt).

proj_disputed() ->
    ok = learning_submitted_v1_to_learnings:project(submit_event(<<"learn-006">>)),
    ok = learning_validated_v1_to_learnings:project(#{
        learning_id => <<"learn-006">>,
        validator_id => <<"v-001">>,
        validated_at => 2000
    }),
    ok = learning_disputed_v1_to_learnings:project(#{
        learning_id => <<"learn-006">>
    }),
    {ok, [[Status, DispCnt]]} =
        query_mentorships_store:query(
            "SELECT status, dispute_count FROM learnings WHERE id = ?1",
            [<<"learn-006">>]),
    %% DISPUTED bit = 16
    ?assert(Status band 16 =/= 0),
    ?assertEqual(1, DispCnt).

proj_resolved() ->
    ok = learning_submitted_v1_to_learnings:project(submit_event(<<"learn-007">>)),
    ok = learning_validated_v1_to_learnings:project(#{
        learning_id => <<"learn-007">>,
        validator_id => <<"v-001">>,
        validated_at => 2000
    }),
    ok = learning_disputed_v1_to_learnings:project(#{
        learning_id => <<"learn-007">>
    }),
    ok = learning_dispute_resolved_v1_to_learnings:project(#{
        learning_id => <<"learn-007">>
    }),
    {ok, [[Status]]} =
        query_mentorships_store:query(
            "SELECT status FROM learnings WHERE id = ?1",
            [<<"learn-007">>]),
    %% RESOLVED bit = 32
    ?assert(Status band 32 =/= 0).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip_by_id() ->
    ok = learning_submitted_v1_to_learnings:project(submit_event(<<"learn-rt1">>)),
    {ok, Map} = get_learning_by_id:execute(<<"learn-rt1">>),
    ?assertEqual(<<"learn-rt1">>, maps:get(id, Map)),
    ?assertEqual(<<"agent-001">>, maps:get(submitter_id, Map)),
    ?assertEqual(<<"antipattern">>, maps:get(category, Map)),
    ?assertEqual(<<"erlang">>, maps:get(domain, Map)),
    ?assertEqual(<<"Avoid blocking gen_server calls">>, maps:get(title, Map)),
    ?assertEqual(1, maps:get(status, Map)),
    ?assertEqual(0, maps:get(endorsement_count, Map)),
    ?assertEqual(0, maps:get(dispute_count, Map)),
    %% Tags decoded from JSON
    ?assertEqual([<<"otp">>, <<"gen_server">>], maps:get(tags, Map)).

roundtrip_page() ->
    Event1 = (submit_event(<<"learn-pg1">>))#{submitted_at => 1000},
    Event2 = (submit_event(<<"learn-pg2">>))#{
        submitter_id => <<"agent-002">>,
        title => <<"Second learning">>,
        submitted_at => 2000
    },
    ok = learning_submitted_v1_to_learnings:project(Event1),
    ok = learning_submitted_v1_to_learnings:project(Event2),
    {ok, Results} = get_learnings_page:execute(#{limit => 50, offset => 0}),
    ?assertEqual(2, length(Results)),
    %% Ordered by submitted_at DESC, so learn-pg2 first
    [First | _] = Results,
    ?assertEqual(<<"learn-pg2">>, maps:get(id, First)).
