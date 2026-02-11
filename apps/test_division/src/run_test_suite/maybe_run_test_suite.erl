-module(maybe_run_test_suite).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case run_test_suite_v1:validate(Cmd) of
        ok ->
            SuiteName = run_test_suite_v1:get_suite_name(Cmd),
            DivisionId = run_test_suite_v1:get_division_id(Cmd),
            SuiteId = <<"suite-", DivisionId/binary, "-", SuiteName/binary>>,
            TestSuites = maps:get(test_suites, Context, #{}),
            case maps:is_key(SuiteId, TestSuites) of
                true ->
                    {error, suite_already_run};
                false ->
                    Event = test_suite_run_v1:new(#{
                        division_id => DivisionId,
                        suite_id => SuiteId,
                        suite_name => SuiteName,
                        suite_type => run_test_suite_v1:get_suite_type(Cmd),
                        target_module => run_test_suite_v1:get_target_module(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = run_test_suite_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = run_test_suite,
        aggregate_type = testing_aggregate,
        aggregate_id = DivisionId,
        payload = run_test_suite_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => testing_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => test_division_store,
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
