-module(maybe_diagnose_incident).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, dispatch/1]).
handle(Cmd) ->
    DI = diagnose_incident_v1:get_division_id(Cmd),
    case validate_command(DI) of ok -> Event = incident_diagnosed_v1:new(#{division_id => DI, diagnosis_id => diagnose_incident_v1:get_diagnosis_id(Cmd), incident_id => diagnose_incident_v1:get_incident_id(Cmd), root_cause => diagnose_incident_v1:get_root_cause(Cmd)}), {ok, [Event]}; {error, R} -> {error, R} end.
dispatch(Cmd) ->
    DI = diagnose_incident_v1:get_division_id(Cmd), Ts = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = diagnose_incident, aggregate_type = division_aggregate, aggregate_id = DI, payload = diagnose_incident_v1:to_map(Cmd), metadata = #{timestamp => Ts, aggregate_type => division_aggregate}, causation_id = undefined, correlation_id = undefined},
    evoq_dispatcher:dispatch(EvoqCmd, #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual}).
validate_command(DI) when is_binary(DI), byte_size(DI) > 0 -> ok; validate_command(_) -> {error, invalid_division_id}.
