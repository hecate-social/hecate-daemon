%%% @doc Projection: test_suite_run_v1 -> test_suites table
-module(test_suite_run_v1_to_sqlite_test_suites).
-export([project/1]).

project(Event) ->
    SuiteId = get(suite_id, Event),
    DivisionId = get(division_id, Event),
    SuiteName = get(suite_name, Event),
    SuiteType = get(suite_type, Event),
    TargetModule = get(target_module, Event),
    RunAt = get(run_at, Event),
    Sql = "INSERT OR REPLACE INTO test_suites "
          "(suite_id, division_id, suite_name, suite_type, target_module, run_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_tests_store:execute(Sql, [SuiteId, DivisionId, SuiteName, SuiteType,
                                    TargetModule, RunAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
