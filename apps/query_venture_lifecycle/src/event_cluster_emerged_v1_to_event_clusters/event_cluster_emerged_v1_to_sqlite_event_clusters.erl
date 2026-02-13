%%% @doc Projection: event_cluster_emerged_v1 -> event_clusters table
-module(event_cluster_emerged_v1_to_sqlite_event_clusters).
-export([project/1]).

project(Event) ->
    ClusterId = get(cluster_id, Event),
    VentureId = get(venture_id, Event),
    StormNumber = get(storm_number, Event, 0),
    Color = get(color, Event),
    CreatedAt = get(emerged_at, Event, erlang:system_time(millisecond)),
    logger:info("[PROJECTION] ~s: projecting cluster ~s", [?MODULE, ClusterId]),
    Sql = "INSERT INTO event_clusters "
          "(cluster_id, venture_id, storm_number, color, status, created_at) "
          "VALUES (?1, ?2, ?3, ?4, 'active', ?5)",
    query_venture_lifecycle_store:execute(Sql, [
        ClusterId, VentureId, StormNumber, Color, CreatedAt
    ]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

get(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.
