%%% @doc Query: list releases for a division with pagination.
-module(get_releases_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT release_id, division_id, release_name, release_version, "
          "target_env, deployed_by, deployed_at "
          "FROM releases WHERE division_id = ?1 "
          "ORDER BY deployed_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_deployments_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({ReleaseId, DivisionId, ReleaseName, ReleaseVersion,
            TargetEnv, DeployedBy, DeployedAt}) ->
    #{
        release_id => ReleaseId,
        division_id => DivisionId,
        release_name => ReleaseName,
        release_version => ReleaseVersion,
        target_env => TargetEnv,
        deployed_by => DeployedBy,
        deployed_at => DeployedAt
    };
row_to_map([ReleaseId, DivisionId, ReleaseName, ReleaseVersion,
            TargetEnv, DeployedBy, DeployedAt]) ->
    row_to_map({ReleaseId, DivisionId, ReleaseName, ReleaseVersion,
                TargetEnv, DeployedBy, DeployedAt}).
