%%% @doc generate_module_v1 command
%%% Generates a module within a division (TnI phase).
-module(generate_module_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_module_name/1, get_module_type/1, get_path/1]).

-record(generate_module_v1, {
    division_id :: binary(),
    module_name :: binary(),
    module_type :: binary() | undefined,
    path        :: binary() | undefined
}).
-export_type([generate_module_v1/0]).
-opaque generate_module_v1() :: #generate_module_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, generate_module_v1()} | {error, term()}.
new(#{division_id := DivisionId, module_name := ModuleName} = Params) ->
    {ok, #generate_module_v1{
        division_id = DivisionId, module_name = ModuleName,
        module_type = maps:get(module_type, Params, undefined),
        path = maps:get(path, Params, undefined)
    }};
new(_) -> {error, missing_required_fields}.

-spec validate(generate_module_v1()) -> {ok, generate_module_v1()} | {error, term()}.
validate(#generate_module_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#generate_module_v1{module_name = N}) when not is_binary(N); byte_size(N) =:= 0 -> {error, invalid_module_name};
validate(#generate_module_v1{} = Cmd) -> {ok, Cmd}.

-spec to_map(generate_module_v1()) -> map().
to_map(#generate_module_v1{} = Cmd) ->
    #{<<"command_type">> => <<"generate_module">>, <<"division_id">> => Cmd#generate_module_v1.division_id,
      <<"module_name">> => Cmd#generate_module_v1.module_name, <<"module_type">> => Cmd#generate_module_v1.module_type,
      <<"path">> => Cmd#generate_module_v1.path}.

-spec from_map(map()) -> {ok, generate_module_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map), ModuleName = get_value(module_name, Map),
    case {DivisionId, ModuleName} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ -> {ok, #generate_module_v1{division_id = DivisionId, module_name = ModuleName,
              module_type = get_value(module_type, Map, undefined), path = get_value(path, Map, undefined)}}
    end.

-spec get_division_id(generate_module_v1()) -> binary().
get_division_id(#generate_module_v1{division_id = V}) -> V.
-spec get_module_name(generate_module_v1()) -> binary().
get_module_name(#generate_module_v1{module_name = V}) -> V.
-spec get_module_type(generate_module_v1()) -> binary() | undefined.
get_module_type(#generate_module_v1{module_type = V}) -> V.
-spec get_path(generate_module_v1()) -> binary() | undefined.
get_path(#generate_module_v1{path = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
