-module(maybe_deploy_release).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case deploy_release_v1:validate(Cmd) of
        ok ->
            ReleaseName = deploy_release_v1:get_release_name(Cmd),
            DivisionId = deploy_release_v1:get_division_id(Cmd),
            ReleaseId = <<"rel-", DivisionId/binary, "-", ReleaseName/binary>>,
            Releases = maps:get(releases, Context, #{}),
            case maps:is_key(ReleaseId, Releases) of
                true ->
                    {error, release_already_deployed};
                false ->
                    Event = release_deployed_v1:new(#{
                        division_id => DivisionId,
                        release_id => ReleaseId,
                        release_name => ReleaseName,
                        release_version => deploy_release_v1:get_release_version(Cmd),
                        target_env => deploy_release_v1:get_target_env(Cmd),
                        deployed_by => deploy_release_v1:get_deployed_by(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = deploy_release_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = deploy_release,
        aggregate_type = deployment_aggregate,
        aggregate_id = DivisionId,
        payload = deploy_release_v1:to_map(Cmd),
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
