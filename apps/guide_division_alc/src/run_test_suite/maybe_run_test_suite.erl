%%% @doc maybe_run_test_suite handler
-module(maybe_run_test_suite).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, handle/2, dispatch/1]).

handle(Cmd) -> handle(Cmd, #{}).
handle(Cmd, Context) ->
    case run_test_suite_v1:validate(Cmd) of
        {ok, _} ->
            SuiteId = run_test_suite_v1:get_suite_id(Cmd),
            Suites = maps:get(test_suites, Context, #{}),
            case maps:is_key(SuiteId, Suites) of
                true -> {error, suite_already_run};
                false ->
                    Event = test_suite_run_v1:new(#{division_id => run_test_suite_v1:get_division_id(Cmd),
                        suite_id => SuiteId, suite_name => run_test_suite_v1:get_suite_name(Cmd)}),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = run_test_suite_v1:get_division_id(Cmd), Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = run_test_suite, aggregate_type = division_aggregate,
        aggregate_id = DivisionId, payload = run_test_suite_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined, correlation_id = undefined},
    Opts = #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
