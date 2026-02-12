%%% @doc test_generated_v1 event
-module(test_generated_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_test_name/1, get_module_name/1, get_path/1, get_generated_at/1]).
-record(test_generated_v1, {division_id :: binary(), test_name :: binary(), module_name :: binary() | undefined, path :: binary() | undefined, generated_at :: integer()}).
-export_type([test_generated_v1/0]).
-opaque test_generated_v1() :: #test_generated_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

new(#{division_id := DivisionId, test_name := TestName} = Params) ->
    #test_generated_v1{division_id = DivisionId, test_name = TestName,
        module_name = maps:get(module_name, Params, undefined), path = maps:get(path, Params, undefined),
        generated_at = erlang:system_time(millisecond)}.

to_map(#test_generated_v1{} = E) ->
    #{<<"event_type">> => <<"test_generated_v1">>, <<"division_id">> => E#test_generated_v1.division_id,
      <<"test_name">> => E#test_generated_v1.test_name, <<"module_name">> => E#test_generated_v1.module_name,
      <<"path">> => E#test_generated_v1.path, <<"generated_at">> => E#test_generated_v1.generated_at}.

from_map(Map) ->
    DivisionId = get_value(division_id, Map), TestName = get_value(test_name, Map),
    case {DivisionId, TestName} of
        {undefined, _} -> {error, invalid_event}; {_, undefined} -> {error, invalid_event};
        _ -> {ok, #test_generated_v1{division_id = DivisionId, test_name = TestName,
              module_name = get_value(module_name, Map, undefined), path = get_value(path, Map, undefined),
              generated_at = get_value(generated_at, Map, erlang:system_time(millisecond))}}
    end.

get_division_id(#test_generated_v1{division_id = V}) -> V.
get_test_name(#test_generated_v1{test_name = V}) -> V.
get_module_name(#test_generated_v1{module_name = V}) -> V.
get_path(#test_generated_v1{path = V}) -> V.
get_generated_at(#test_generated_v1{generated_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
