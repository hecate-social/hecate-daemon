%%% @doc Projection: event_sticky_clustered_v1 -> event_stickies table
-module(event_sticky_clustered_v1_to_sqlite_event_stickies).
-export([project/1]).

project(Event) ->
    ClusterId = get(cluster_id, Event),
    StickyId = get(sticky_id, Event),
    logger:info("[PROJECTION] ~s: clustering sticky ~s into ~s", [?MODULE, StickyId, ClusterId]),
    Sql = "UPDATE event_stickies SET cluster_id = ?1 WHERE sticky_id = ?2",
    query_venture_lifecycle_store:execute(Sql, [ClusterId, StickyId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
