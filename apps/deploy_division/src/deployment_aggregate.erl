%%% @doc Aggregate for the deployment process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands: deploy_release (only when active),
%%%                  stage_rollout (only when active)
%%% Stream: deployment-{division_id}
%%% @end
-module(deployment_aggregate).

-behaviour(evoq_aggregate).

-include_lib("deploy_division/include/deployment_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(deployment_state, {
    division_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    releases = #{} :: #{binary() => map()},
    rollout_stages = #{} :: #{binary() => map()},
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #deployment_state{}}.

%% --- Execute: lifecycle commands ---

%% Start deployment (only on fresh aggregate)
execute(#deployment_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_deployment">> -> execute_start_deployment(Payload);
        _ -> {error, deployment_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#deployment_state{status = S} = State, Payload)
  when S band ?DEPLOYMENT_ARCHIVED =:= 0, S band ?DEPLOYMENT_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_deployment">> -> execute_archive_deployment(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#deployment_state{status = S}, _Payload)
  when S band ?DEPLOYMENT_ARCHIVED =/= 0 ->
    {error, deployment_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"deploy_release">>, Payload, #deployment_state{status = S} = State)
  when S band ?DEPLOYMENT_ACTIVE =/= 0 ->
    execute_deploy_release(Payload, State);
execute_lifecycle(<<"deploy_release">>, _Payload, #deployment_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"stage_rollout">>, Payload, #deployment_state{status = S} = State)
  when S band ?DEPLOYMENT_ACTIVE =/= 0 ->
    execute_stage_rollout(Payload, State);
execute_lifecycle(<<"stage_rollout">>, _Payload, #deployment_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_deployment">>, Payload, #deployment_state{status = S} = State)
  when S band ?DEPLOYMENT_ACTIVE =/= 0 ->
    execute_pause_deployment(Payload, State);
execute_lifecycle(<<"pause_deployment">>, _Payload, #deployment_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_deployment">>, Payload, #deployment_state{status = S} = State)
  when S band ?DEPLOYMENT_PAUSED =/= 0 ->
    execute_resume_deployment(Payload, State);
execute_lifecycle(<<"resume_deployment">>, _Payload, #deployment_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_deployment">>, Payload, #deployment_state{status = S} = State)
  when S band ?DEPLOYMENT_ACTIVE =/= 0 ->
    execute_complete_deployment(Payload, State);
execute_lifecycle(<<"complete_deployment">>, _Payload, #deployment_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_deployment(Payload) ->
    {ok, Cmd} = start_deployment_v1:from_map(Payload),
    convert_events(maybe_start_deployment:handle(Cmd), fun deployment_started_v1:to_map/1).

execute_deploy_release(Payload, #deployment_state{releases = Releases}) ->
    {ok, Cmd} = deploy_release_v1:from_map(Payload),
    Context = #{releases => Releases},
    convert_events(maybe_deploy_release:handle(Cmd, Context), fun release_deployed_v1:to_map/1).

execute_stage_rollout(Payload, #deployment_state{rollout_stages = Stages}) ->
    {ok, Cmd} = stage_rollout_v1:from_map(Payload),
    Context = #{rollout_stages => Stages},
    convert_events(maybe_stage_rollout:handle(Cmd, Context), fun rollout_staged_v1:to_map/1).

execute_pause_deployment(Payload, _State) ->
    {ok, Cmd} = pause_deployment_v1:from_map(Payload),
    convert_events(maybe_pause_deployment:handle(Cmd), fun deployment_paused_v1:to_map/1).

execute_resume_deployment(Payload, _State) ->
    {ok, Cmd} = resume_deployment_v1:from_map(Payload),
    convert_events(maybe_resume_deployment:handle(Cmd), fun deployment_resumed_v1:to_map/1).

execute_complete_deployment(Payload, _State) ->
    {ok, Cmd} = complete_deployment_v1:from_map(Payload),
    convert_events(maybe_complete_deployment:handle(Cmd), fun deployment_completed_v1:to_map/1).

execute_archive_deployment(Payload, _State) ->
    {ok, Cmd} = archive_deployment_v1:from_map(Payload),
    convert_events(maybe_archive_deployment:handle(Cmd), fun deployment_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"deployment_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"deployment_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"release_deployed_v1">>} = E) ->
    apply_release_deployed(E, State);
apply(State, #{event_type := <<"release_deployed_v1">>} = E) ->
    apply_release_deployed(E, State);

apply(State, #{<<"event_type">> := <<"rollout_staged_v1">>} = E) ->
    apply_rollout_staged(E, State);
apply(State, #{event_type := <<"rollout_staged_v1">>} = E) ->
    apply_rollout_staged(E, State);

apply(State, #{<<"event_type">> := <<"deployment_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"deployment_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"deployment_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"deployment_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"deployment_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"deployment_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"deployment_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"deployment_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?DEPLOYMENT_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?DEPLOYMENT_ACTIVE),
    State#deployment_state{
        division_id = get_value(division_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_release_deployed(E, State) ->
    ReleaseId = get_value(release_id, E),
    Details = #{
        release_id => ReleaseId,
        release_name => get_value(release_name, E),
        release_version => get_value(release_version, E),
        target_env => get_value(target_env, E),
        deployed_by => get_value(deployed_by, E),
        deployed_at => get_value(deployed_at, E)
    },
    Releases = State#deployment_state.releases,
    State#deployment_state{
        releases = Releases#{ReleaseId => Details}
    }.

apply_rollout_staged(E, State) ->
    StageId = get_value(stage_id, E),
    Details = #{
        stage_id => StageId,
        release_id => get_value(release_id, E),
        stage_name => get_value(stage_name, E),
        stage_percentage => get_value(stage_percentage, E),
        description => get_value(description, E),
        staged_at => get_value(staged_at, E)
    },
    Stages = State#deployment_state.rollout_stages,
    State#deployment_state{
        rollout_stages = Stages#{StageId => Details}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#deployment_state.status, ?DEPLOYMENT_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?DEPLOYMENT_PAUSED),
    State#deployment_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#deployment_state.status, ?DEPLOYMENT_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?DEPLOYMENT_ACTIVE),
    State#deployment_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#deployment_state.status, ?DEPLOYMENT_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?DEPLOYMENT_COMPLETED),
    State#deployment_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#deployment_state{
        status = evoq_bit_flags:set(State#deployment_state.status, ?DEPLOYMENT_ARCHIVED)
    }.

%% --- Internal ---

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key),
            maps:get(BinKey, Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
