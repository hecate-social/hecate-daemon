%%% @doc Projection: release_deployed_v1 -> releases table
-module(release_deployed_v1_to_sqlite_releases).
-export([project/1]).

project(Event) ->
    ReleaseId = get(release_id, Event),
    DivisionId = get(division_id, Event),
    ReleaseName = get(release_name, Event),
    ReleaseVersion = get(release_version, Event),
    TargetEnv = get(target_env, Event),
    DeployedBy = get(deployed_by, Event),
    DeployedAt = get(deployed_at, Event),
    Sql = "INSERT OR REPLACE INTO releases "
          "(release_id, division_id, release_name, release_version, "
          "target_env, deployed_by, deployed_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    query_deployments_store:execute(Sql, [ReleaseId, DivisionId, ReleaseName,
                                          ReleaseVersion, TargetEnv,
                                          DeployedBy, DeployedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
