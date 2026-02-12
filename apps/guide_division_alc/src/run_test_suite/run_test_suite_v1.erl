%%% @doc run_test_suite_v1 command
-module(run_test_suite_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_suite_id/1, get_suite_name/1]).
-export([generate_id/0]).
-record(run_test_suite_v1, {division_id :: binary(), suite_id :: binary(), suite_name :: binary()}).
-export_type([run_test_suite_v1/0]).
-opaque run_test_suite_v1() :: #run_test_suite_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

new(#{division_id := DivisionId, suite_name := SuiteName} = Params) ->
    {ok, #run_test_suite_v1{division_id = DivisionId, suite_id = maps:get(suite_id, Params, generate_id()), suite_name = SuiteName}};
new(_) -> {error, missing_required_fields}.

validate(#run_test_suite_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#run_test_suite_v1{suite_name = N}) when not is_binary(N); byte_size(N) =:= 0 -> {error, invalid_suite_name};
validate(#run_test_suite_v1{} = Cmd) -> {ok, Cmd}.

to_map(#run_test_suite_v1{} = C) ->
    #{<<"command_type">> => <<"run_test_suite">>, <<"division_id">> => C#run_test_suite_v1.division_id,
      <<"suite_id">> => C#run_test_suite_v1.suite_id, <<"suite_name">> => C#run_test_suite_v1.suite_name}.

from_map(Map) ->
    DivisionId = get_value(division_id, Map), SuiteName = get_value(suite_name, Map),
    case {DivisionId, SuiteName} of
        {undefined, _} -> {error, missing_required_fields}; {_, undefined} -> {error, missing_required_fields};
        _ -> {ok, #run_test_suite_v1{division_id = DivisionId, suite_id = get_value(suite_id, Map, generate_id()), suite_name = SuiteName}}
    end.

get_division_id(#run_test_suite_v1{division_id = V}) -> V.
get_suite_id(#run_test_suite_v1{suite_id = V}) -> V.
get_suite_name(#run_test_suite_v1{suite_name = V}) -> V.

generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"suite-", Ts/binary, "-", Rand/binary>>.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
