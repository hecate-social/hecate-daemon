-module(maybe_record_test_result).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case record_test_result_v1:validate(Cmd) of
        ok ->
            SuiteId = record_test_result_v1:get_suite_id(Cmd),
            TestName = record_test_result_v1:get_test_name(Cmd),
            ResultId = <<"result-", SuiteId/binary, "-", TestName/binary>>,
            TestResults = maps:get(test_results, Context, #{}),
            case maps:is_key(ResultId, TestResults) of
                true ->
                    {error, result_already_recorded};
                false ->
                    Event = test_result_recorded_v1:new(#{
                        division_id => record_test_result_v1:get_division_id(Cmd),
                        result_id => ResultId,
                        suite_id => SuiteId,
                        test_name => TestName,
                        status => record_test_result_v1:get_status(Cmd),
                        details => record_test_result_v1:get_details(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = record_test_result_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = record_test_result,
        aggregate_type = testing_aggregate,
        aggregate_id = DivisionId,
        payload = record_test_result_v1:to_map(Cmd),
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
