%%% @doc generate_test_v1 command
-module(generate_test_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_test_name/1, get_module_name/1, get_path/1]).
-record(generate_test_v1, {division_id :: binary(), test_name :: binary(), module_name :: binary() | undefined, path :: binary() | undefined}).
-export_type([generate_test_v1/0]).
-opaque generate_test_v1() :: #generate_test_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

new(#{division_id := DivisionId, test_name := TestName} = Params) ->
    {ok, #generate_test_v1{division_id = DivisionId, test_name = TestName,
        module_name = maps:get(module_name, Params, undefined), path = maps:get(path, Params, undefined)}};
new(_) -> {error, missing_required_fields}.

validate(#generate_test_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#generate_test_v1{test_name = N}) when not is_binary(N); byte_size(N) =:= 0 -> {error, invalid_test_name};
validate(#generate_test_v1{} = Cmd) -> {ok, Cmd}.

to_map(#generate_test_v1{} = C) ->
    #{<<"command_type">> => <<"generate_test">>, <<"division_id">> => C#generate_test_v1.division_id,
      <<"test_name">> => C#generate_test_v1.test_name, <<"module_name">> => C#generate_test_v1.module_name,
      <<"path">> => C#generate_test_v1.path}.

from_map(Map) ->
    DivisionId = get_value(division_id, Map), TestName = get_value(test_name, Map),
    case {DivisionId, TestName} of
        {undefined, _} -> {error, missing_required_fields}; {_, undefined} -> {error, missing_required_fields};
        _ -> {ok, #generate_test_v1{division_id = DivisionId, test_name = TestName,
              module_name = get_value(module_name, Map, undefined), path = get_value(path, Map, undefined)}}
    end.

get_division_id(#generate_test_v1{division_id = V}) -> V.
get_test_name(#generate_test_v1{test_name = V}) -> V.
get_module_name(#generate_test_v1{module_name = V}) -> V.
get_path(#generate_test_v1{path = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
