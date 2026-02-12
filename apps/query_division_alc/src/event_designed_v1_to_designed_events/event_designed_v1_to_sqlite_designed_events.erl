%%% @doc Projection: event_designed_v1 -> designed_events table
-module(event_designed_v1_to_sqlite_designed_events).
-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    EventName = get(event_name, Event),
    Description = get(description, Event),
    AggregateName = get(aggregate_name, Event),
    Fields = encode_json(get(fields, Event)),
    DesignedAt = get(designed_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, EventName]),
    Sql = "INSERT OR REPLACE INTO designed_events "
          "(division_id, event_name, description, aggregate_name, "
          "fields, designed_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_division_alc_store:execute(Sql, [DivisionId, EventName, Description,
                                           AggregateName, Fields, DesignedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

encode_json(undefined) -> undefined;
encode_json(null) -> undefined;
encode_json(Value) when is_list(Value); is_map(Value) ->
    iolist_to_binary(json:encode(Value));
encode_json(Value) when is_binary(Value) -> Value.
