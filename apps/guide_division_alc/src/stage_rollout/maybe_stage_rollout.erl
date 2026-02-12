-module(maybe_stage_rollout).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, dispatch/1]).
handle(Cmd) ->
    DI = stage_rollout_v1:get_division_id(Cmd),
    case validate_command(DI) of ok -> Event = rollout_staged_v1:new(#{division_id => DI, stage_id => stage_rollout_v1:get_stage_id(Cmd), release_id => stage_rollout_v1:get_release_id(Cmd), stage_name => stage_rollout_v1:get_stage_name(Cmd)}), {ok, [Event]}; {error, R} -> {error, R} end.
dispatch(Cmd) ->
    DI = stage_rollout_v1:get_division_id(Cmd), Ts = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = stage_rollout, aggregate_type = division_aggregate, aggregate_id = DI, payload = stage_rollout_v1:to_map(Cmd), metadata = #{timestamp => Ts, aggregate_type => division_aggregate}, causation_id = undefined, correlation_id = undefined},
    evoq_dispatcher:dispatch(EvoqCmd, #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual}).
validate_command(DI) when is_binary(DI), byte_size(DI) > 0 -> ok; validate_command(_) -> {error, invalid_division_id}.
