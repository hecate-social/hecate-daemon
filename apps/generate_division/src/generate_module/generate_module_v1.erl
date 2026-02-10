-module(generate_module_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_module_name/1, get_module_type/1,
         get_file_path/1, get_content/1, get_description/1,
         get_generated_by/1]).

-record(generate_module_v1, {
    division_id :: binary(),
    module_name :: binary(),
    module_type :: binary(),
    file_path :: binary(),
    content :: binary(),
    description :: binary() | undefined,
    generated_by :: binary() | undefined
}).

new(#{division_id := DivisionId, module_name := ModuleName} = Params) ->
    Cmd = #generate_module_v1{
        division_id = DivisionId,
        module_name = ModuleName,
        module_type = maps:get(module_type, Params, <<"command">>),
        file_path = maps:get(file_path, Params, <<>>),
        content = maps:get(content, Params, <<>>),
        description = maps:get(description, Params, undefined),
        generated_by = maps:get(generated_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#generate_module_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#generate_module_v1{module_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, module_name}};
validate(_) -> ok.

to_map(#generate_module_v1{division_id = DI, module_name = MN, module_type = MT,
                            file_path = FP, content = C, description = D,
                            generated_by = GB}) ->
    #{
        <<"command_type">> => <<"generate_module">>,
        <<"division_id">> => DI,
        <<"module_name">> => MN,
        <<"module_type">> => MT,
        <<"file_path">> => FP,
        <<"content">> => C,
        <<"description">> => D,
        <<"generated_by">> => GB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    ModuleName = get_val(module_name, Map),
    ModuleType = get_val(module_type, Map),
    FilePath = get_val(file_path, Map),
    Content = get_val(content, Map),
    Description = get_val(description, Map),
    GeneratedBy = get_val(generated_by, Map),
    new(#{division_id => DivisionId, module_name => ModuleName,
          module_type => ModuleType, file_path => FilePath,
          content => Content, description => Description,
          generated_by => GeneratedBy}).

get_division_id(#generate_module_v1{division_id = V}) -> V.
get_module_name(#generate_module_v1{module_name = V}) -> V.
get_module_type(#generate_module_v1{module_type = V}) -> V.
get_file_path(#generate_module_v1{file_path = V}) -> V.
get_content(#generate_module_v1{content = V}) -> V.
get_description(#generate_module_v1{description = V}) -> V.
get_generated_by(#generate_module_v1{generated_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
