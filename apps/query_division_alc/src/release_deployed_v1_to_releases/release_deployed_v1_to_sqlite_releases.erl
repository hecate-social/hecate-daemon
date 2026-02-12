%%% @doc Projection: release_deployed_v1 -> releases table
-module(release_deployed_v1_to_sqlite_releases).
-export([project/1]).

project(Event) ->
    ReleaseId = get(release_id, Event),
    DivisionId = get(division_id, Event),
    Version = get(version, Event),
    DeployedAt = get(deployed_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, ReleaseId]),
    Sql = "INSERT OR REPLACE INTO releases "
          "(release_id, division_id, version, deployed_at) "
          "VALUES (?1, ?2, ?3, ?4)",
    query_division_alc_store:execute(Sql, [ReleaseId, DivisionId, Version, DeployedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
