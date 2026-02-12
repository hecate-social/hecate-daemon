%%% @doc maybe_deploy_release handler (handle/1 only)
-module(maybe_deploy_release).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, dispatch/1]).

handle(Cmd) ->
    DivisionId = deploy_release_v1:get_division_id(Cmd),
    case validate_command(DivisionId) of
        ok -> Event = release_deployed_v1:new(#{division_id => DivisionId, release_id => deploy_release_v1:get_release_id(Cmd), version => deploy_release_v1:get_version(Cmd)}), {ok, [Event]};
        {error, Reason} -> {error, Reason}
    end.

dispatch(Cmd) ->
    DivisionId = deploy_release_v1:get_division_id(Cmd), Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = deploy_release, aggregate_type = division_aggregate, aggregate_id = DivisionId, payload = deploy_release_v1:to_map(Cmd), metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate}, causation_id = undefined, correlation_id = undefined},
    Opts = #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

validate_command(DivisionId) when is_binary(DivisionId), byte_size(DivisionId) > 0 -> ok;
validate_command(_) -> {error, invalid_division_id}.
