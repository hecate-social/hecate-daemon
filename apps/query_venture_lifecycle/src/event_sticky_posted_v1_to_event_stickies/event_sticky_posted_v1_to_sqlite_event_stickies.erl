%%% @doc Projection: event_sticky_posted_v1 -> event_stickies table
-module(event_sticky_posted_v1_to_sqlite_event_stickies).
-export([project/1]).

project(Event) ->
    StickyId = get(sticky_id, Event),
    VentureId = get(venture_id, Event),
    StormNumber = get(storm_number, Event),
    Text = get(text, Event),
    Author = get(author, Event, <<"user">>),
    CreatedAt = get(created_at, Event),
    logger:info("[PROJECTION] ~s: projecting sticky ~s", [?MODULE, StickyId]),
    Sql = "INSERT INTO event_stickies "
          "(sticky_id, venture_id, storm_number, text, author, weight, created_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, 1, ?6)",
    query_venture_lifecycle_store:execute(Sql, [
        StickyId, VentureId, StormNumber, Text, Author, CreatedAt
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
