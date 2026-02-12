%%% @doc maybe_record_test_result handler (handle/1 only)
-module(maybe_record_test_result).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, dispatch/1]).

handle(Cmd) ->
    DivisionId = record_test_result_v1:get_division_id(Cmd),
    case validate_command(DivisionId) of
        ok ->
            Event = test_result_recorded_v1:new(#{division_id => DivisionId,
                result_id => record_test_result_v1:get_result_id(Cmd),
                suite_id => record_test_result_v1:get_suite_id(Cmd),
                passed => record_test_result_v1:get_passed(Cmd),
                failed => record_test_result_v1:get_failed(Cmd)}),
            {ok, [Event]};
        {error, Reason} -> {error, Reason}
    end.

dispatch(Cmd) ->
    DivisionId = record_test_result_v1:get_division_id(Cmd), Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = record_test_result, aggregate_type = division_aggregate,
        aggregate_id = DivisionId, payload = record_test_result_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined, correlation_id = undefined},
    Opts = #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

validate_command(DivisionId) when is_binary(DivisionId), byte_size(DivisionId) > 0 -> ok;
validate_command(_) -> {error, invalid_division_id}.
