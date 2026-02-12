%%% @doc maybe_generate_test handler
-module(maybe_generate_test).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, handle/2, dispatch/1]).

handle(Cmd) -> handle(Cmd, #{}).
handle(Cmd, Context) ->
    case generate_test_v1:validate(Cmd) of
        {ok, _} ->
            TestName = generate_test_v1:get_test_name(Cmd),
            GenTests = maps:get(generated_tests, Context, #{}),
            case maps:is_key(TestName, GenTests) of
                true -> {error, test_already_generated};
                false ->
                    Event = test_generated_v1:new(#{division_id => generate_test_v1:get_division_id(Cmd),
                        test_name => TestName, module_name => generate_test_v1:get_module_name(Cmd),
                        path => generate_test_v1:get_path(Cmd)}),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = generate_test_v1:get_division_id(Cmd), Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = generate_test, aggregate_type = division_aggregate,
        aggregate_id = DivisionId, payload = generate_test_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined, correlation_id = undefined},
    Opts = #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
