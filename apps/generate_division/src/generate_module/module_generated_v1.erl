-module(module_generated_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_module_id/1, get_module_name/1,
         get_module_type/1, get_file_path/1, get_content/1,
         get_description/1, get_generated_by/1, get_generated_at/1]).

-record(module_generated_v1, {
    division_id :: binary(),
    module_id :: binary(),
    module_name :: binary(),
    module_type :: binary(),
    file_path :: binary(),
    content :: binary(),
    description :: binary() | undefined,
    generated_by :: binary() | undefined,
    generated_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, module_name := ModuleName} = Params) ->
    #module_generated_v1{
        division_id = DivisionId,
        module_id = maps:get(module_id, Params, generate_module_id()),
        module_name = ModuleName,
        module_type = maps:get(module_type, Params, <<"command">>),
        file_path = maps:get(file_path, Params, <<>>),
        content = maps:get(content, Params, <<>>),
        description = maps:get(description, Params, undefined),
        generated_by = maps:get(generated_by, Params, undefined),
        generated_at = maps:get(generated_at, Params, erlang:system_time(millisecond))
    }.

to_map(#module_generated_v1{division_id = DI, module_id = MId, module_name = MN,
                             module_type = MT, file_path = FP, content = C,
                             description = D, generated_by = GB, generated_at = GA}) ->
    #{
        <<"event_type">> => <<"module_generated_v1">>,
        <<"division_id">> => DI,
        <<"module_id">> => MId,
        <<"module_name">> => MN,
        <<"module_type">> => MT,
        <<"file_path">> => FP,
        <<"content">> => C,
        <<"description">> => D,
        <<"generated_by">> => GB,
        <<"generated_at">> => GA
    }.

from_map(Map) ->
    {ok, #module_generated_v1{
        division_id = get_val(division_id, Map),
        module_id = get_val(module_id, Map),
        module_name = get_val(module_name, Map),
        module_type = get_val(module_type, Map),
        file_path = get_val(file_path, Map),
        content = get_val(content, Map),
        description = get_val(description, Map),
        generated_by = get_val(generated_by, Map),
        generated_at = get_val(generated_at, Map)
    }}.

get_division_id(#module_generated_v1{division_id = V}) -> V.
get_module_id(#module_generated_v1{module_id = V}) -> V.
get_module_name(#module_generated_v1{module_name = V}) -> V.
get_module_type(#module_generated_v1{module_type = V}) -> V.
get_file_path(#module_generated_v1{file_path = V}) -> V.
get_content(#module_generated_v1{content = V}) -> V.
get_description(#module_generated_v1{description = V}) -> V.
get_generated_by(#module_generated_v1{generated_by = V}) -> V.
get_generated_at(#module_generated_v1{generated_at = V}) -> V.

generate_module_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"mod-", Ts/binary, "-", Rand/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
