%%% @doc Projection: event_sticky_stacked_v1 -> event_stickies table
-module(event_sticky_stacked_v1_to_sqlite_event_stickies).
-export([project/1]).

project(Event) ->
    StackId = get(stack_id, Event),
    StickyId = get(sticky_id, Event),
    logger:info("[PROJECTION] ~s: stacking sticky ~s into ~s", [?MODULE, StickyId, StackId]),
    Sql = "UPDATE event_stickies SET stack_id = ?1 WHERE sticky_id = ?2",
    query_venture_lifecycle_store:execute(Sql, [StackId, StickyId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
