%%% @doc Query: list test suites for a division with pagination.
-module(get_test_suites_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT suite_id, division_id, suite_name, suite_type, "
          "target_module, run_at "
          "FROM test_suites WHERE division_id = ?1 "
          "ORDER BY run_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_tests_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({SuiteId, DivisionId, SuiteName, SuiteType,
            TargetModule, RunAt}) ->
    #{
        suite_id => SuiteId,
        division_id => DivisionId,
        suite_name => SuiteName,
        suite_type => SuiteType,
        target_module => TargetModule,
        run_at => RunAt
    };
row_to_map([SuiteId, DivisionId, SuiteName, SuiteType,
            TargetModule, RunAt]) ->
    row_to_map({SuiteId, DivisionId, SuiteName, SuiteType,
                TargetModule, RunAt}).
