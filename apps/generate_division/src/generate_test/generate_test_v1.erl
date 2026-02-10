-module(generate_test_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_test_name/1, get_test_type/1,
         get_module_name/1, get_file_path/1, get_content/1,
         get_description/1, get_generated_by/1]).

-record(generate_test_v1, {
    division_id :: binary(),
    test_name :: binary(),
    test_type :: binary(),
    module_name :: binary(),
    file_path :: binary(),
    content :: binary(),
    description :: binary() | undefined,
    generated_by :: binary() | undefined
}).

new(#{division_id := DivisionId, test_name := TestName} = Params) ->
    Cmd = #generate_test_v1{
        division_id = DivisionId,
        test_name = TestName,
        test_type = maps:get(test_type, Params, <<"unit">>),
        module_name = maps:get(module_name, Params, <<>>),
        file_path = maps:get(file_path, Params, <<>>),
        content = maps:get(content, Params, <<>>),
        description = maps:get(description, Params, undefined),
        generated_by = maps:get(generated_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#generate_test_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#generate_test_v1{test_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, test_name}};
validate(_) -> ok.

to_map(#generate_test_v1{division_id = DI, test_name = TN, test_type = TT,
                          module_name = MN, file_path = FP, content = C,
                          description = D, generated_by = GB}) ->
    #{
        <<"command_type">> => <<"generate_test">>,
        <<"division_id">> => DI,
        <<"test_name">> => TN,
        <<"test_type">> => TT,
        <<"module_name">> => MN,
        <<"file_path">> => FP,
        <<"content">> => C,
        <<"description">> => D,
        <<"generated_by">> => GB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    TestName = get_val(test_name, Map),
    TestType = get_val(test_type, Map),
    ModuleName = get_val(module_name, Map),
    FilePath = get_val(file_path, Map),
    Content = get_val(content, Map),
    Description = get_val(description, Map),
    GeneratedBy = get_val(generated_by, Map),
    new(#{division_id => DivisionId, test_name => TestName,
          test_type => TestType, module_name => ModuleName,
          file_path => FilePath, content => Content,
          description => Description, generated_by => GeneratedBy}).

get_division_id(#generate_test_v1{division_id = V}) -> V.
get_test_name(#generate_test_v1{test_name = V}) -> V.
get_test_type(#generate_test_v1{test_type = V}) -> V.
get_module_name(#generate_test_v1{module_name = V}) -> V.
get_file_path(#generate_test_v1{file_path = V}) -> V.
get_content(#generate_test_v1{content = V}) -> V.
get_description(#generate_test_v1{description = V}) -> V.
get_generated_by(#generate_test_v1{generated_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
