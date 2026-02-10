-module(run_test_suite_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_suite_name/1, get_suite_type/1,
         get_target_module/1]).

-record(run_test_suite_v1, {
    division_id :: binary(),
    suite_name :: binary(),
    suite_type :: binary(),
    target_module :: binary()
}).

new(#{division_id := DivisionId, suite_name := SuiteName} = Params) ->
    Cmd = #run_test_suite_v1{
        division_id = DivisionId,
        suite_name = SuiteName,
        suite_type = maps:get(suite_type, Params, <<"unit">>),
        target_module = maps:get(target_module, Params, <<>>)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#run_test_suite_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#run_test_suite_v1{suite_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, suite_name}};
validate(_) -> ok.

to_map(#run_test_suite_v1{division_id = DI, suite_name = SN, suite_type = ST,
                           target_module = TM}) ->
    #{
        <<"command_type">> => <<"run_test_suite">>,
        <<"division_id">> => DI,
        <<"suite_name">> => SN,
        <<"suite_type">> => ST,
        <<"target_module">> => TM
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    SuiteName = get_val(suite_name, Map),
    SuiteType = get_val(suite_type, Map),
    TargetModule = get_val(target_module, Map),
    new(#{division_id => DivisionId, suite_name => SuiteName,
          suite_type => SuiteType, target_module => TargetModule}).

get_division_id(#run_test_suite_v1{division_id = V}) -> V.
get_suite_name(#run_test_suite_v1{suite_name = V}) -> V.
get_suite_type(#run_test_suite_v1{suite_type = V}) -> V.
get_target_module(#run_test_suite_v1{target_module = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
