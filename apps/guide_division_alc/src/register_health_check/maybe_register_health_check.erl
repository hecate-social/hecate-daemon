-module(maybe_register_health_check).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, dispatch/1]).
handle(Cmd) ->
    DI = register_health_check_v1:get_division_id(Cmd),
    case validate_command(DI) of ok -> Event = health_check_registered_v1:new(#{division_id => DI, check_id => register_health_check_v1:get_check_id(Cmd), check_name => register_health_check_v1:get_check_name(Cmd), check_type => register_health_check_v1:get_check_type(Cmd)}), {ok, [Event]}; {error, R} -> {error, R} end.
dispatch(Cmd) ->
    DI = register_health_check_v1:get_division_id(Cmd), Ts = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = register_health_check, aggregate_type = division_aggregate, aggregate_id = DI, payload = register_health_check_v1:to_map(Cmd), metadata = #{timestamp => Ts, aggregate_type => division_aggregate}, causation_id = undefined, correlation_id = undefined},
    evoq_dispatcher:dispatch(EvoqCmd, #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual}).
validate_command(DI) when is_binary(DI), byte_size(DI) > 0 -> ok; validate_command(_) -> {error, invalid_division_id}.
