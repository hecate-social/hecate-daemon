%%% @doc Projection: event_cluster_named_v1 -> event_clusters table
-module(event_cluster_named_v1_to_sqlite_event_clusters).
-export([project/1]).

project(Event) ->
    Name = get(name, Event),
    ClusterId = get(cluster_id, Event),
    logger:info("[PROJECTION] ~s: naming cluster ~s as ~s", [?MODULE, ClusterId, Name]),
    Sql = "UPDATE event_clusters SET name = ?1 WHERE cluster_id = ?2",
    query_venture_lifecycle_store:execute(Sql, [Name, ClusterId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
