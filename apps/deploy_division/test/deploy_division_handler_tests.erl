%%% @doc Layer 2b+2c: Handler + Aggregate execute/2 tests.
%%% Tests handle/1 business logic and execute/2 state machine guards.
%%% No I/O — builds state via apply/2 chains, then tests commands.
-module(deploy_division_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("deploy_division/include/deployment_status.hrl").

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = deployment_aggregate:init(<<>>),
    S.

started_state() ->
    deployment_aggregate:apply(fresh_state(), start_event_map()).

paused_state() ->
    deployment_aggregate:apply(started_state(), pause_event_map()).

completed_state() ->
    deployment_aggregate:apply(started_state(), complete_event_map()).

archived_state() ->
    deployment_aggregate:apply(started_state(), archive_event_map()).

start_event_map() ->
    #{<<"event_type">> => <<"deployment_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

release_deployed_event_map() ->
    #{<<"event_type">> => <<"release_deployed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"release_id">> => <<"rel-div-1-myapp">>,
      <<"release_name">> => <<"myapp">>,
      <<"release_version">> => <<"1.0.0">>,
      <<"target_env">> => <<"production">>,
      <<"deployed_by">> => <<"deployer@host">>,
      <<"deployed_at">> => 2000}.

pause_event_map() ->
    #{<<"event_type">> => <<"deployment_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"incident">>}.

complete_event_map() ->
    #{<<"event_type">> => <<"deployment_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event_map() ->
    #{<<"event_type">> => <<"deployment_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin@host">>,
      <<"reason">> => <<"cleanup">>}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% --- maybe_start_deployment ---

handle_valid_start_test() ->
    {ok, Cmd} = start_deployment_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_deployment:handle(Cmd),
    Map = deployment_started_v1:to_map(Event),
    ?assertEqual(<<"deployment_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_start_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 start_deployment_v1:new(#{division_id => <<>>})).

%% --- maybe_deploy_release ---

handle_valid_deploy_release_test() ->
    {ok, Cmd} = deploy_release_v1:new(#{
        division_id => <<"div-1">>,
        release_name => <<"myapp">>,
        release_version => <<"1.0.0">>,
        target_env => <<"production">>,
        deployed_by => <<"deployer@host">>
    }),
    Context = #{releases => #{}},
    {ok, [Event]} = maybe_deploy_release:handle(Cmd, Context),
    Map = release_deployed_v1:to_map(Event),
    ?assertEqual(<<"release_deployed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"myapp">>, maps:get(<<"release_name">>, Map)),
    ?assertEqual(<<"1.0.0">>, maps:get(<<"release_version">>, Map)),
    ?assertEqual(<<"production">>, maps:get(<<"target_env">>, Map)).

handle_deploy_release_duplicate_test() ->
    {ok, Cmd} = deploy_release_v1:new(#{
        division_id => <<"div-1">>,
        release_name => <<"myapp">>
    }),
    Context = #{releases => #{<<"rel-div-1-myapp">> => #{}}},
    ?assertEqual({error, release_already_deployed},
                 maybe_deploy_release:handle(Cmd, Context)).

handle_deploy_release_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 deploy_release_v1:new(#{division_id => <<>>, release_name => <<"app">>})),
    ?assertEqual({error, {invalid_field, release_name}},
                 deploy_release_v1:new(#{division_id => <<"div-1">>, release_name => <<>>})).

%% --- maybe_stage_rollout ---

handle_valid_stage_rollout_test() ->
    {ok, Cmd} = stage_rollout_v1:new(#{
        division_id => <<"div-1">>,
        release_id => <<"rel-div-1-myapp">>,
        stage_name => <<"canary">>,
        stage_percentage => 10,
        description => <<"Canary rollout">>
    }),
    Context = #{rollout_stages => #{}},
    {ok, [Event]} = maybe_stage_rollout:handle(Cmd, Context),
    Map = rollout_staged_v1:to_map(Event),
    ?assertEqual(<<"rollout_staged_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"canary">>, maps:get(<<"stage_name">>, Map)),
    ?assertEqual(10, maps:get(<<"stage_percentage">>, Map)).

handle_stage_rollout_duplicate_test() ->
    {ok, Cmd} = stage_rollout_v1:new(#{
        division_id => <<"div-1">>,
        release_id => <<"rel-div-1-myapp">>,
        stage_name => <<"canary">>
    }),
    Context = #{rollout_stages => #{<<"stage-rel-div-1-myapp-canary">> => #{}}},
    ?assertEqual({error, stage_already_exists},
                 maybe_stage_rollout:handle(Cmd, Context)).

handle_stage_rollout_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 stage_rollout_v1:new(#{division_id => <<>>,
                                       release_id => <<"r">>,
                                       stage_name => <<"s">>})),
    ?assertEqual({error, {invalid_field, release_id}},
                 stage_rollout_v1:new(#{division_id => <<"d">>,
                                       release_id => <<>>,
                                       stage_name => <<"s">>})),
    ?assertEqual({error, {invalid_field, stage_name}},
                 stage_rollout_v1:new(#{division_id => <<"d">>,
                                       release_id => <<"r">>,
                                       stage_name => <<>>})).

%% --- maybe_pause_deployment ---

handle_valid_pause_test() ->
    {ok, Cmd} = pause_deployment_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"incident detected">>
    }),
    {ok, [Event]} = maybe_pause_deployment:handle(Cmd),
    Map = deployment_paused_v1:to_map(Event),
    ?assertEqual(<<"deployment_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"incident detected">>, maps:get(<<"reason">>, Map)).

%% --- maybe_resume_deployment ---

handle_valid_resume_test() ->
    {ok, Cmd} = resume_deployment_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_resume_deployment:handle(Cmd),
    Map = deployment_resumed_v1:to_map(Event),
    ?assertEqual(<<"deployment_resumed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

%% --- maybe_complete_deployment ---

handle_valid_complete_test() ->
    {ok, Cmd} = complete_deployment_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_complete_deployment:handle(Cmd),
    Map = deployment_completed_v1:to_map(Event),
    ?assertEqual(<<"deployment_completed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

%% --- maybe_archive_deployment ---

handle_valid_archive_test() ->
    {ok, Cmd} = archive_deployment_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_deployment:handle(Cmd),
    Map = deployment_archived_v1:to_map(Event),
    ?assertEqual(<<"deployment_archived_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_deployment command ---

execute_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"start_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = deployment_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"deployment_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_rejects_non_start_on_fresh_test() ->
    Cmd = #{<<"command_type">> => <<"pause_deployment">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, deployment_not_started},
                 deployment_aggregate:execute(fresh_state(), Cmd)).

%% --- deploy_release command ---

execute_deploy_release_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"deploy_release">>,
            <<"division_id">> => <<"div-1">>,
            <<"release_name">> => <<"myapp">>,
            <<"release_version">> => <<"1.0.0">>,
            <<"target_env">> => <<"production">>},
    {ok, [EventMap]} = deployment_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"release_deployed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_deploy_release_not_active_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"deploy_release">>,
            <<"division_id">> => <<"div-1">>,
            <<"release_name">> => <<"myapp">>},
    {error, {not_active, _S}} = deployment_aggregate:execute(paused_state(), Cmd).

execute_deploy_release_not_active_when_completed_test() ->
    Cmd = #{<<"command_type">> => <<"deploy_release">>,
            <<"division_id">> => <<"div-1">>,
            <<"release_name">> => <<"myapp">>},
    {error, {not_active, _S}} = deployment_aggregate:execute(completed_state(), Cmd).

%% --- stage_rollout command ---

execute_stage_rollout_on_active_test() ->
    %% First deploy a release so the stage can reference it
    WithRelease = deployment_aggregate:apply(started_state(), release_deployed_event_map()),
    Cmd = #{<<"command_type">> => <<"stage_rollout">>,
            <<"division_id">> => <<"div-1">>,
            <<"release_id">> => <<"rel-div-1-myapp">>,
            <<"stage_name">> => <<"canary">>,
            <<"stage_percentage">> => 10},
    {ok, [EventMap]} = deployment_aggregate:execute(WithRelease, Cmd),
    ?assertEqual(<<"rollout_staged_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_stage_rollout_not_active_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"stage_rollout">>,
            <<"division_id">> => <<"div-1">>,
            <<"release_id">> => <<"rel-div-1-myapp">>,
            <<"stage_name">> => <<"canary">>},
    {error, {not_active, _S}} = deployment_aggregate:execute(paused_state(), Cmd).

%% --- pause_deployment command ---

execute_pause_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_deployment">>,
            <<"division_id">> => <<"div-1">>,
            <<"reason">> => <<"incident">>},
    {ok, [EventMap]} = deployment_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"deployment_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_not_active_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"pause_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {error, {not_active, _S}} = deployment_aggregate:execute(paused_state(), Cmd).

execute_pause_not_active_when_completed_test() ->
    Cmd = #{<<"command_type">> => <<"pause_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {error, {not_active, _S}} = deployment_aggregate:execute(completed_state(), Cmd).

%% --- resume_deployment command ---

execute_resume_on_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = deployment_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"deployment_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_not_paused_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"resume_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {error, {not_paused, _S}} = deployment_aggregate:execute(started_state(), Cmd).

execute_resume_not_paused_when_completed_test() ->
    Cmd = #{<<"command_type">> => <<"resume_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {error, {not_paused, _S}} = deployment_aggregate:execute(completed_state(), Cmd).

%% --- complete_deployment command ---

execute_complete_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = deployment_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"deployment_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_not_active_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"complete_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {error, {not_active, _S}} = deployment_aggregate:execute(paused_state(), Cmd).

execute_complete_not_active_when_completed_test() ->
    Cmd = #{<<"command_type">> => <<"complete_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {error, {not_active, _S}} = deployment_aggregate:execute(completed_state(), Cmd).

%% --- archive_deployment command ---

execute_archive_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = deployment_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"deployment_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_paused_test() ->
    Cmd = #{<<"command_type">> => <<"archive_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = deployment_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"deployment_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_completed_test() ->
    Cmd = #{<<"command_type">> => <<"archive_deployment">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = deployment_aggregate:execute(completed_state(), Cmd),
    ?assertEqual(<<"deployment_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_deployment">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, deployment_archived},
                 deployment_aggregate:execute(archived_state(), Cmd)).

execute_archive_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_deployment">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, deployment_not_started},
                 deployment_aggregate:execute(fresh_state(), Cmd)).

%% --- unknown command ---

execute_unknown_command_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 deployment_aggregate:execute(started_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertEqual({error, deployment_not_started},
                 deployment_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_deployment">>,
                <<"division_id">> => <<"div-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = deployment_aggregate:execute(State, Payload).

%% --- pause/resume cycle then complete ---

execute_pause_resume_complete_cycle_test() ->
    S0 = started_state(),
    %% Pause
    PauseCmd = #{<<"command_type">> => <<"pause_deployment">>,
                 <<"division_id">> => <<"div-1">>,
                 <<"reason">> => <<"issue">>},
    {ok, [PauseEvent]} = deployment_aggregate:execute(S0, PauseCmd),
    S1 = deployment_aggregate:apply(S0, PauseEvent),
    %% Resume
    ResumeCmd = #{<<"command_type">> => <<"resume_deployment">>,
                  <<"division_id">> => <<"div-1">>},
    {ok, [ResumeEvent]} = deployment_aggregate:execute(S1, ResumeCmd),
    S2 = deployment_aggregate:apply(S1, ResumeEvent),
    %% Complete
    CompleteCmd = #{<<"command_type">> => <<"complete_deployment">>,
                   <<"division_id">> => <<"div-1">>},
    {ok, [CompleteEvent]} = deployment_aggregate:execute(S2, CompleteCmd),
    ?assertEqual(<<"deployment_completed_v1">>, maps:get(<<"event_type">>, CompleteEvent)).
