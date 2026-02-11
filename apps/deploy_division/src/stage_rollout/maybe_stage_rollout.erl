-module(maybe_stage_rollout).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case stage_rollout_v1:validate(Cmd) of
        ok ->
            ReleaseId = stage_rollout_v1:get_release_id(Cmd),
            StageName = stage_rollout_v1:get_stage_name(Cmd),
            StageId = <<"stage-", ReleaseId/binary, "-", StageName/binary>>,
            Stages = maps:get(rollout_stages, Context, #{}),
            case maps:is_key(StageId, Stages) of
                true ->
                    {error, stage_already_exists};
                false ->
                    Event = rollout_staged_v1:new(#{
                        division_id => stage_rollout_v1:get_division_id(Cmd),
                        stage_id => StageId,
                        release_id => ReleaseId,
                        stage_name => StageName,
                        stage_percentage => stage_rollout_v1:get_stage_percentage(Cmd),
                        description => stage_rollout_v1:get_description(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = stage_rollout_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = stage_rollout,
        aggregate_type = deployment_aggregate,
        aggregate_id = DivisionId,
        payload = stage_rollout_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => deployment_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => deploy_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

generate_command_id(DivisionId, Timestamp) ->
    Unique = integer_to_binary(erlang:unique_integer([positive])),
    Hash = crypto:hash(sha256, <<DivisionId/binary, (integer_to_binary(Timestamp))/binary, "-", Unique/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
