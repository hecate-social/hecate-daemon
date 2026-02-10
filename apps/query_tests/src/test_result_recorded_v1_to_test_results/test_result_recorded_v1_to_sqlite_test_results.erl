%%% @doc Projection: test_result_recorded_v1 -> test_results table
-module(test_result_recorded_v1_to_sqlite_test_results).
-export([project/1]).

project(Event) ->
    ResultId = get(result_id, Event),
    DivisionId = get(division_id, Event),
    SuiteId = get(suite_id, Event),
    TestName = get(test_name, Event),
    Status = get(status, Event),
    Details = get(details, Event),
    RecordedAt = get(recorded_at, Event),
    Sql = "INSERT OR REPLACE INTO test_results "
          "(result_id, division_id, suite_id, test_name, status, details, recorded_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    query_tests_store:execute(Sql, [ResultId, DivisionId, SuiteId, TestName,
                                    Status, Details, RecordedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
