%%% @doc record_test_result_v1 command
-module(record_test_result_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_result_id/1, get_suite_id/1, get_passed/1, get_failed/1]).
-export([generate_id/0]).
-record(record_test_result_v1, {division_id :: binary(), result_id :: binary(), suite_id :: binary(), passed :: non_neg_integer(), failed :: non_neg_integer()}).
-export_type([record_test_result_v1/0]).
-opaque record_test_result_v1() :: #record_test_result_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

new(#{division_id := DivisionId, suite_id := SuiteId} = Params) ->
    {ok, #record_test_result_v1{division_id = DivisionId, result_id = maps:get(result_id, Params, generate_id()),
        suite_id = SuiteId, passed = maps:get(passed, Params, 0), failed = maps:get(failed, Params, 0)}};
new(_) -> {error, missing_required_fields}.

validate(#record_test_result_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#record_test_result_v1{suite_id = S}) when not is_binary(S); byte_size(S) =:= 0 -> {error, invalid_suite_id};
validate(#record_test_result_v1{} = Cmd) -> {ok, Cmd}.

to_map(#record_test_result_v1{} = C) ->
    #{<<"command_type">> => <<"record_test_result">>, <<"division_id">> => C#record_test_result_v1.division_id,
      <<"result_id">> => C#record_test_result_v1.result_id, <<"suite_id">> => C#record_test_result_v1.suite_id,
      <<"passed">> => C#record_test_result_v1.passed, <<"failed">> => C#record_test_result_v1.failed}.

from_map(Map) ->
    DivisionId = get_value(division_id, Map), SuiteId = get_value(suite_id, Map),
    case {DivisionId, SuiteId} of
        {undefined, _} -> {error, missing_required_fields}; {_, undefined} -> {error, missing_required_fields};
        _ -> {ok, #record_test_result_v1{division_id = DivisionId, result_id = get_value(result_id, Map, generate_id()),
              suite_id = SuiteId, passed = get_value(passed, Map, 0), failed = get_value(failed, Map, 0)}}
    end.

get_division_id(#record_test_result_v1{division_id = V}) -> V.
get_result_id(#record_test_result_v1{result_id = V}) -> V.
get_suite_id(#record_test_result_v1{suite_id = V}) -> V.
get_passed(#record_test_result_v1{passed = V}) -> V.
get_failed(#record_test_result_v1{failed = V}) -> V.
generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)), <<"result-", Ts/binary, "-", Rand/binary>>.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) -> BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
