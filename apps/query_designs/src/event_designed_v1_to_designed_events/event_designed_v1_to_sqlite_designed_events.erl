%%% @doc Projection: event_designed_v1 -> designed_events table
-module(event_designed_v1_to_sqlite_designed_events).
-export([project/1]).

project(Event) ->
    EventId = get(event_id, Event),
    DivisionId = get(division_id, Event),
    EventName = get(event_name, Event),
    AggregateName = get(aggregate_name, Event),
    PayloadFields = encode_json(get(payload_fields, Event)),
    Description = get(description, Event),
    DesignedBy = get(designed_by, Event),
    DesignedAt = get(designed_at, Event),
    Sql = "INSERT OR REPLACE INTO designed_events "
          "(event_id, division_id, event_name, aggregate_name, "
          "payload_fields, description, designed_by, designed_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
    query_designs_store:execute(Sql, [EventId, DivisionId, EventName,
                                      AggregateName, PayloadFields, Description,
                                      DesignedBy, DesignedAt]).

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
