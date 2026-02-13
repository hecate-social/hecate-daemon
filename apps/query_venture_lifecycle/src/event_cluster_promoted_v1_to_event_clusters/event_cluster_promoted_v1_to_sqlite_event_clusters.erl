%%% @doc Projection: event_cluster_promoted_v1 -> event_clusters table
-module(event_cluster_promoted_v1_to_sqlite_event_clusters).
-export([project/1]).

project(Event) ->
    ClusterId = get(cluster_id, Event),
    logger:info("[PROJECTION] ~s: promoting cluster ~s", [?MODULE, ClusterId]),
    Sql = "UPDATE event_clusters SET status = 'promoted' WHERE cluster_id = ?1",
    query_venture_lifecycle_store:execute(Sql, [ClusterId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
