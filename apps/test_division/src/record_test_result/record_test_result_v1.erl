-module(record_test_result_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_suite_id/1, get_test_name/1,
         get_status/1, get_details/1]).

-record(record_test_result_v1, {
    division_id :: binary(),
    suite_id :: binary(),
    test_name :: binary(),
    status :: binary(),
    details :: binary() | undefined
}).

new(#{division_id := DivisionId, suite_id := SuiteId, test_name := TestName} = Params) ->
    Cmd = #record_test_result_v1{
        division_id = DivisionId,
        suite_id = SuiteId,
        test_name = TestName,
        status = maps:get(status, Params, <<"unknown">>),
        details = maps:get(details, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#record_test_result_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#record_test_result_v1{suite_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, suite_id}};
validate(#record_test_result_v1{test_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, test_name}};
validate(_) -> ok.

to_map(#record_test_result_v1{division_id = DI, suite_id = SI, test_name = TN,
                               status = S, details = D}) ->
    #{
        <<"command_type">> => <<"record_test_result">>,
        <<"division_id">> => DI,
        <<"suite_id">> => SI,
        <<"test_name">> => TN,
        <<"status">> => S,
        <<"details">> => D
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    SuiteId = get_val(suite_id, Map),
    TestName = get_val(test_name, Map),
    Status = get_val(status, Map),
    Details = get_val(details, Map),
    new(#{division_id => DivisionId, suite_id => SuiteId,
          test_name => TestName, status => Status, details => Details}).

get_division_id(#record_test_result_v1{division_id = V}) -> V.
get_suite_id(#record_test_result_v1{suite_id = V}) -> V.
get_test_name(#record_test_result_v1{test_name = V}) -> V.
get_status(#record_test_result_v1{status = V}) -> V.
get_details(#record_test_result_v1{details = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
