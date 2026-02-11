%%% @doc Layer 1: Dossier Tests — Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since deployment_state record is internal to deployment_aggregate,
%%% we verify state correctness through execute/2 behavior (state machine
%%% guards) and through the behaviour callback apply/2.
-module(deployment_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("deploy_division/include/deployment_status.hrl").

%% Record field positions in deployment_state (record tag is element 1)
-define(F_DIVISION_ID,    2).
-define(F_STATUS,         3).
-define(F_RELEASES,       4).
-define(F_ROLLOUT_STAGES, 5).
-define(F_STARTED_AT,     6).
-define(F_PAUSED_AT,      7).
-define(F_COMPLETED_AT,   8).
-define(F_PAUSE_REASON,   9).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"deployment_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

release_deployed_event() ->
    #{<<"event_type">> => <<"release_deployed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"release_id">> => <<"rel-div-1-myapp">>,
      <<"release_name">> => <<"myapp">>,
      <<"release_version">> => <<"1.0.0">>,
      <<"target_env">> => <<"production">>,
      <<"deployed_by">> => <<"deployer@host">>,
      <<"deployed_at">> => 2000}.

rollout_staged_event() ->
    #{<<"event_type">> => <<"rollout_staged_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"release_id">> => <<"rel-div-1-myapp">>,
      <<"stage_id">> => <<"stage-rel-div-1-myapp-canary">>,
      <<"stage_name">> => <<"canary">>,
      <<"stage_percentage">> => 10,
      <<"description">> => <<"Canary rollout">>,
      <<"staged_at">> => 3000}.

pause_event() ->
    #{<<"event_type">> => <<"deployment_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"incident detected">>}.

resume_event() ->
    #{<<"event_type">> => <<"deployment_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 5000}.

complete_event() ->
    #{<<"event_type">> => <<"deployment_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event() ->
    #{<<"event_type">> => <<"deployment_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin@host">>,
      <<"reason">> => <<"cleanup">>}.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% init/1 callback returns {ok, zeroed state}
init_callback_test() ->
    {ok, S} = deployment_aggregate:init(<<"any-id">>),
    ?assertEqual(undefined, element(?F_DIVISION_ID, S)),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual(#{}, element(?F_RELEASES, S)),
    ?assertEqual(#{}, element(?F_ROLLOUT_STAGES, S)),
    ?assertEqual(undefined, element(?F_STARTED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S)),
    ?assertEqual(undefined, element(?F_COMPLETED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S)).

%% Apply deployment_started_v1 sets INITIATED + ACTIVE, populates fields
apply_started_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    Status = element(?F_STATUS, S1),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_INITIATED),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_ACTIVE),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(1000, element(?F_STARTED_AT, S1)).

%% Apply release_deployed_v1 adds release to releases map
apply_release_deployed_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, release_deployed_event()),
    Releases = element(?F_RELEASES, S2),
    ?assert(maps:is_key(<<"rel-div-1-myapp">>, Releases)),
    Details = maps:get(<<"rel-div-1-myapp">>, Releases),
    ?assertEqual(<<"myapp">>, maps:get(release_name, Details)),
    ?assertEqual(<<"1.0.0">>, maps:get(release_version, Details)),
    ?assertEqual(<<"production">>, maps:get(target_env, Details)),
    ?assertEqual(<<"deployer@host">>, maps:get(deployed_by, Details)),
    ?assertEqual(2000, maps:get(deployed_at, Details)).

%% Apply rollout_staged_v1 adds stage to rollout_stages map
apply_rollout_staged_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, release_deployed_event()),
    S3 = deployment_aggregate:apply(S2, rollout_staged_event()),
    Stages = element(?F_ROLLOUT_STAGES, S3),
    ?assert(maps:is_key(<<"stage-rel-div-1-myapp-canary">>, Stages)),
    Details = maps:get(<<"stage-rel-div-1-myapp-canary">>, Stages),
    ?assertEqual(<<"canary">>, maps:get(stage_name, Details)),
    ?assertEqual(10, maps:get(stage_percentage, Details)),
    ?assertEqual(<<"Canary rollout">>, maps:get(description, Details)),
    ?assertEqual(3000, maps:get(staged_at, Details)).

%% Apply deployment_paused_v1 unsets ACTIVE, sets PAUSED, stores reason
apply_paused_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, pause_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_PAUSED),
    ?assertEqual(0, Status band ?DEPLOYMENT_ACTIVE),
    ?assertEqual(4000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"incident detected">>, element(?F_PAUSE_REASON, S2)).

%% Apply deployment_resumed_v1 unsets PAUSED, sets ACTIVE, clears pause fields
apply_resumed_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, pause_event()),
    S3 = deployment_aggregate:apply(S2, resume_event()),
    Status = element(?F_STATUS, S3),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_ACTIVE),
    ?assertEqual(0, Status band ?DEPLOYMENT_PAUSED),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).

%% Apply deployment_completed_v1 unsets ACTIVE, sets COMPLETED
apply_completed_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, complete_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_COMPLETED),
    ?assertEqual(0, Status band ?DEPLOYMENT_ACTIVE),
    ?assertEqual(6000, element(?F_COMPLETED_AT, S2)).

%% Apply deployment_archived_v1 sets ARCHIVED bit
apply_archived_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, archive_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_ARCHIVED),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_INITIATED).

%% Full lifecycle: start -> deploy -> stage -> pause -> resume -> complete -> archive
full_lifecycle_state_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, release_deployed_event()),
    S3 = deployment_aggregate:apply(S2, rollout_staged_event()),
    S4 = deployment_aggregate:apply(S3, pause_event()),
    S5 = deployment_aggregate:apply(S4, resume_event()),
    S6 = deployment_aggregate:apply(S5, complete_event()),
    S7 = deployment_aggregate:apply(S6, archive_event()),
    Status = element(?F_STATUS, S7),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_INITIATED),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_COMPLETED),
    ?assertNotEqual(0, Status band ?DEPLOYMENT_ARCHIVED),
    ?assertEqual(0, Status band ?DEPLOYMENT_ACTIVE),
    ?assertEqual(0, Status band ?DEPLOYMENT_PAUSED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S7)),
    ?assert(maps:is_key(<<"rel-div-1-myapp">>, element(?F_RELEASES, S7))),
    ?assert(maps:is_key(<<"stage-rel-div-1-myapp-canary">>, element(?F_ROLLOUT_STAGES, S7))).

%% Multiple releases accumulate in the releases map
multiple_releases_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, release_deployed_event()),
    SecondRelease = #{<<"event_type">> => <<"release_deployed_v1">>,
                      <<"division_id">> => <<"div-1">>,
                      <<"release_id">> => <<"rel-div-1-backend">>,
                      <<"release_name">> => <<"backend">>,
                      <<"release_version">> => <<"2.0.0">>,
                      <<"target_env">> => <<"staging">>,
                      <<"deployed_by">> => <<"dev@host">>,
                      <<"deployed_at">> => 2500},
    S3 = deployment_aggregate:apply(S2, SecondRelease),
    Releases = element(?F_RELEASES, S3),
    ?assertEqual(2, maps:size(Releases)),
    ?assert(maps:is_key(<<"rel-div-1-myapp">>, Releases)),
    ?assert(maps:is_key(<<"rel-div-1-backend">>, Releases)).

%% Multiple rollout stages accumulate in the stages map
multiple_stages_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, release_deployed_event()),
    S3 = deployment_aggregate:apply(S2, rollout_staged_event()),
    SecondStage = #{<<"event_type">> => <<"rollout_staged_v1">>,
                    <<"division_id">> => <<"div-1">>,
                    <<"release_id">> => <<"rel-div-1-myapp">>,
                    <<"stage_id">> => <<"stage-rel-div-1-myapp-full">>,
                    <<"stage_name">> => <<"full">>,
                    <<"stage_percentage">> => 100,
                    <<"description">> => <<"Full rollout">>,
                    <<"staged_at">> => 3500},
    S4 = deployment_aggregate:apply(S3, SecondStage),
    Stages = element(?F_ROLLOUT_STAGES, S4),
    ?assertEqual(2, maps:size(Stages)),
    ?assert(maps:is_key(<<"stage-rel-div-1-myapp-canary">>, Stages)),
    ?assert(maps:is_key(<<"stage-rel-div-1-myapp-full">>, Stages)).

%% Unknown event leaves state unchanged
apply_unknown_event_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    Unknown = #{<<"event_type">> => <<"some_random_event">>, <<"data">> => <<"whatever">>},
    S2 = deployment_aggregate:apply(S1, Unknown),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
apply_with_atom_keys_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    AtomEvent = #{event_type => <<"deployment_started_v1">>,
                  division_id => <<"div-atom">>,
                  started_at => 9000,
                  started_by => <<"atom@host">>},
    S1 = deployment_aggregate:apply(S0, AtomEvent),
    ?assertEqual(<<"div-atom">>, element(?F_DIVISION_ID, S1)),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DEPLOYMENT_INITIATED).

%% Pause -> resume cycle clears paused_at and pause_reason
pause_resume_clears_fields_test() ->
    {ok, S0} = deployment_aggregate:init(<<>>),
    S1 = deployment_aggregate:apply(S0, start_event()),
    S2 = deployment_aggregate:apply(S1, pause_event()),
    %% Verify pause fields are set
    ?assertEqual(4000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"incident detected">>, element(?F_PAUSE_REASON, S2)),
    %% Resume clears them
    S3 = deployment_aggregate:apply(S2, resume_event()),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).
