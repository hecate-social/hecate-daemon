-module(test_suite_run_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_suite_id/1, get_suite_name/1,
         get_suite_type/1, get_target_module/1, get_run_at/1]).

-record(test_suite_run_v1, {
    division_id :: binary(),
    suite_id :: binary(),
    suite_name :: binary(),
    suite_type :: binary(),
    target_module :: binary(),
    run_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, suite_name := SuiteName} = Params) ->
    SuiteId = maps:get(suite_id, Params, generate_suite_id(DivisionId, SuiteName)),
    #test_suite_run_v1{
        division_id = DivisionId,
        suite_id = SuiteId,
        suite_name = SuiteName,
        suite_type = maps:get(suite_type, Params, <<"unit">>),
        target_module = maps:get(target_module, Params, <<>>),
        run_at = maps:get(run_at, Params, erlang:system_time(millisecond))
    }.

to_map(#test_suite_run_v1{division_id = DI, suite_id = SI, suite_name = SN,
                           suite_type = ST, target_module = TM, run_at = RA}) ->
    #{
        <<"event_type">> => <<"test_suite_run_v1">>,
        <<"division_id">> => DI,
        <<"suite_id">> => SI,
        <<"suite_name">> => SN,
        <<"suite_type">> => ST,
        <<"target_module">> => TM,
        <<"run_at">> => RA
    }.

from_map(Map) ->
    {ok, #test_suite_run_v1{
        division_id = get_val(division_id, Map),
        suite_id = get_val(suite_id, Map),
        suite_name = get_val(suite_name, Map),
        suite_type = get_val(suite_type, Map),
        target_module = get_val(target_module, Map),
        run_at = get_val(run_at, Map)
    }}.

get_division_id(#test_suite_run_v1{division_id = V}) -> V.
get_suite_id(#test_suite_run_v1{suite_id = V}) -> V.
get_suite_name(#test_suite_run_v1{suite_name = V}) -> V.
get_suite_type(#test_suite_run_v1{suite_type = V}) -> V.
get_target_module(#test_suite_run_v1{target_module = V}) -> V.
get_run_at(#test_suite_run_v1{run_at = V}) -> V.

generate_suite_id(DivisionId, SuiteName) ->
    <<"suite-", DivisionId/binary, "-", SuiteName/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
