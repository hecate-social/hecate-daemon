%%% @doc Projection: test_suite_run_v1 -> test_suites table
-module(test_suite_run_v1_to_sqlite_test_suites).
-export([project/1]).

project(Event) ->
    SuiteId = get(suite_id, Event),
    DivisionId = get(division_id, Event),
    SuiteName = get(suite_name, Event),
    RunAt = get(run_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, SuiteId]),
    Sql = "INSERT OR REPLACE INTO test_suites "
          "(suite_id, division_id, suite_name, run_at) "
          "VALUES (?1, ?2, ?3, ?4)",
    query_division_alc_store:execute(Sql, [SuiteId, DivisionId, SuiteName, RunAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
