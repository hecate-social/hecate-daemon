%%% @doc Query: list test results for a division with pagination.
-module(get_test_results_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT result_id, division_id, suite_id, test_name, "
          "status, details, recorded_at "
          "FROM test_results WHERE division_id = ?1 "
          "ORDER BY recorded_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_tests_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({ResultId, DivisionId, SuiteId, TestName,
            Status, Details, RecordedAt}) ->
    #{
        result_id => ResultId,
        division_id => DivisionId,
        suite_id => SuiteId,
        test_name => TestName,
        status => Status,
        details => Details,
        recorded_at => RecordedAt
    };
row_to_map([ResultId, DivisionId, SuiteId, TestName,
            Status, Details, RecordedAt]) ->
    row_to_map({ResultId, DivisionId, SuiteId, TestName,
                Status, Details, RecordedAt}).
