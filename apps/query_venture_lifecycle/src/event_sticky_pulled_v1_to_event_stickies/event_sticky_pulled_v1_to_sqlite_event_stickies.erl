%%% @doc Projection: event_sticky_pulled_v1 -> event_stickies table
-module(event_sticky_pulled_v1_to_sqlite_event_stickies).
-export([project/1]).

project(Event) ->
    StickyId = get(sticky_id, Event),
    logger:info("[PROJECTION] ~s: pulling sticky ~s", [?MODULE, StickyId]),
    Sql = "DELETE FROM event_stickies WHERE sticky_id = ?1",
    query_venture_lifecycle_store:execute(Sql, [StickyId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
