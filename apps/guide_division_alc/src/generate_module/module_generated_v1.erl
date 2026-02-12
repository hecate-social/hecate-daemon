%%% @doc module_generated_v1 event
-module(module_generated_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_module_name/1, get_module_type/1, get_path/1, get_generated_at/1]).

-record(module_generated_v1, {
    division_id  :: binary(), module_name :: binary(), module_type :: binary() | undefined,
    path :: binary() | undefined, generated_at :: integer()
}).
-export_type([module_generated_v1/0]).
-opaque module_generated_v1() :: #module_generated_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> module_generated_v1().
new(#{division_id := DivisionId, module_name := ModuleName} = Params) ->
    #module_generated_v1{division_id = DivisionId, module_name = ModuleName,
        module_type = maps:get(module_type, Params, undefined),
        path = maps:get(path, Params, undefined),
        generated_at = erlang:system_time(millisecond)}.

-spec to_map(module_generated_v1()) -> map().
to_map(#module_generated_v1{} = E) ->
    #{<<"event_type">> => <<"module_generated_v1">>, <<"division_id">> => E#module_generated_v1.division_id,
      <<"module_name">> => E#module_generated_v1.module_name, <<"module_type">> => E#module_generated_v1.module_type,
      <<"path">> => E#module_generated_v1.path, <<"generated_at">> => E#module_generated_v1.generated_at}.

-spec from_map(map()) -> {ok, module_generated_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map), ModuleName = get_value(module_name, Map),
    case {DivisionId, ModuleName} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ -> {ok, #module_generated_v1{division_id = DivisionId, module_name = ModuleName,
              module_type = get_value(module_type, Map, undefined), path = get_value(path, Map, undefined),
              generated_at = get_value(generated_at, Map, erlang:system_time(millisecond))}}
    end.

-spec get_division_id(module_generated_v1()) -> binary().
get_division_id(#module_generated_v1{division_id = V}) -> V.
-spec get_module_name(module_generated_v1()) -> binary().
get_module_name(#module_generated_v1{module_name = V}) -> V.
-spec get_module_type(module_generated_v1()) -> binary() | undefined.
get_module_type(#module_generated_v1{module_type = V}) -> V.
-spec get_path(module_generated_v1()) -> binary() | undefined.
get_path(#module_generated_v1{path = V}) -> V.
-spec get_generated_at(module_generated_v1()) -> integer().
get_generated_at(#module_generated_v1{generated_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
