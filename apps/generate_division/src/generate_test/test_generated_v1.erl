-module(test_generated_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_test_id/1, get_test_name/1,
         get_test_type/1, get_module_name/1, get_file_path/1,
         get_content/1, get_description/1, get_generated_by/1,
         get_generated_at/1]).

-record(test_generated_v1, {
    division_id :: binary(),
    test_id :: binary(),
    test_name :: binary(),
    test_type :: binary(),
    module_name :: binary(),
    file_path :: binary(),
    content :: binary(),
    description :: binary() | undefined,
    generated_by :: binary() | undefined,
    generated_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, test_name := TestName} = Params) ->
    #test_generated_v1{
        division_id = DivisionId,
        test_id = maps:get(test_id, Params, generate_test_id()),
        test_name = TestName,
        test_type = maps:get(test_type, Params, <<"unit">>),
        module_name = maps:get(module_name, Params, <<>>),
        file_path = maps:get(file_path, Params, <<>>),
        content = maps:get(content, Params, <<>>),
        description = maps:get(description, Params, undefined),
        generated_by = maps:get(generated_by, Params, undefined),
        generated_at = maps:get(generated_at, Params, erlang:system_time(millisecond))
    }.

to_map(#test_generated_v1{division_id = DI, test_id = TId, test_name = TN,
                           test_type = TT, module_name = MN, file_path = FP,
                           content = C, description = D, generated_by = GB,
                           generated_at = GA}) ->
    #{
        <<"event_type">> => <<"test_generated_v1">>,
        <<"division_id">> => DI,
        <<"test_id">> => TId,
        <<"test_name">> => TN,
        <<"test_type">> => TT,
        <<"module_name">> => MN,
        <<"file_path">> => FP,
        <<"content">> => C,
        <<"description">> => D,
        <<"generated_by">> => GB,
        <<"generated_at">> => GA
    }.

from_map(Map) ->
    {ok, #test_generated_v1{
        division_id = get_val(division_id, Map),
        test_id = get_val(test_id, Map),
        test_name = get_val(test_name, Map),
        test_type = get_val(test_type, Map),
        module_name = get_val(module_name, Map),
        file_path = get_val(file_path, Map),
        content = get_val(content, Map),
        description = get_val(description, Map),
        generated_by = get_val(generated_by, Map),
        generated_at = get_val(generated_at, Map)
    }}.

get_division_id(#test_generated_v1{division_id = V}) -> V.
get_test_id(#test_generated_v1{test_id = V}) -> V.
get_test_name(#test_generated_v1{test_name = V}) -> V.
get_test_type(#test_generated_v1{test_type = V}) -> V.
get_module_name(#test_generated_v1{module_name = V}) -> V.
get_file_path(#test_generated_v1{file_path = V}) -> V.
get_content(#test_generated_v1{content = V}) -> V.
get_description(#test_generated_v1{description = V}) -> V.
get_generated_by(#test_generated_v1{generated_by = V}) -> V.
get_generated_at(#test_generated_v1{generated_at = V}) -> V.

generate_test_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"tst-", Ts/binary, "-", Rand/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
