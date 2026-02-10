%%% @doc Query: list rollout stages for a division with pagination.
-module(get_rollout_stages_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT stage_id, division_id, release_id, stage_name, "
          "stage_percentage, description, staged_at "
          "FROM rollout_stages WHERE division_id = ?1 "
          "ORDER BY staged_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_deployments_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({StageId, DivisionId, ReleaseId, StageName,
            StagePercentage, Description, StagedAt}) ->
    #{
        stage_id => StageId,
        division_id => DivisionId,
        release_id => ReleaseId,
        stage_name => StageName,
        stage_percentage => StagePercentage,
        description => Description,
        staged_at => StagedAt
    };
row_to_map([StageId, DivisionId, ReleaseId, StageName,
            StagePercentage, Description, StagedAt]) ->
    row_to_map({StageId, DivisionId, ReleaseId, StageName,
                StagePercentage, Description, StagedAt}).
