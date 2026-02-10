-module(test_result_recorded_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_result_id/1, get_suite_id/1,
         get_test_name/1, get_status/1, get_details/1, get_recorded_at/1]).

-record(test_result_recorded_v1, {
    division_id :: binary(),
    result_id :: binary(),
    suite_id :: binary(),
    test_name :: binary(),
    status :: binary(),
    details :: binary() | undefined,
    recorded_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, suite_id := SuiteId, test_name := TestName} = Params) ->
    ResultId = maps:get(result_id, Params, generate_result_id(SuiteId, TestName)),
    #test_result_recorded_v1{
        division_id = DivisionId,
        result_id = ResultId,
        suite_id = SuiteId,
        test_name = TestName,
        status = maps:get(status, Params, <<"unknown">>),
        details = maps:get(details, Params, undefined),
        recorded_at = maps:get(recorded_at, Params, erlang:system_time(millisecond))
    }.

to_map(#test_result_recorded_v1{division_id = DI, result_id = RI, suite_id = SI,
                                 test_name = TN, status = S, details = D,
                                 recorded_at = RA}) ->
    #{
        <<"event_type">> => <<"test_result_recorded_v1">>,
        <<"division_id">> => DI,
        <<"result_id">> => RI,
        <<"suite_id">> => SI,
        <<"test_name">> => TN,
        <<"status">> => S,
        <<"details">> => D,
        <<"recorded_at">> => RA
    }.

from_map(Map) ->
    {ok, #test_result_recorded_v1{
        division_id = get_val(division_id, Map),
        result_id = get_val(result_id, Map),
        suite_id = get_val(suite_id, Map),
        test_name = get_val(test_name, Map),
        status = get_val(status, Map),
        details = get_val(details, Map),
        recorded_at = get_val(recorded_at, Map)
    }}.

get_division_id(#test_result_recorded_v1{division_id = V}) -> V.
get_result_id(#test_result_recorded_v1{result_id = V}) -> V.
get_suite_id(#test_result_recorded_v1{suite_id = V}) -> V.
get_test_name(#test_result_recorded_v1{test_name = V}) -> V.
get_status(#test_result_recorded_v1{status = V}) -> V.
get_details(#test_result_recorded_v1{details = V}) -> V.
get_recorded_at(#test_result_recorded_v1{recorded_at = V}) -> V.

generate_result_id(SuiteId, TestName) ->
    <<"result-", SuiteId/binary, "-", TestName/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
