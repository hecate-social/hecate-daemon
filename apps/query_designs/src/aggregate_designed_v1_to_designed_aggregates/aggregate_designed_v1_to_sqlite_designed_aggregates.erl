%%% @doc Projection: aggregate_designed_v1 -> designed_aggregates table
-module(aggregate_designed_v1_to_sqlite_designed_aggregates).
-export([project/1]).

project(Event) ->
    AggregateId = get(aggregate_id, Event),
    DivisionId = get(division_id, Event),
    AggregateName = get(aggregate_name, Event),
    StreamPattern = get(stream_pattern, Event),
    StatusFlags = encode_json(get(status_flags, Event)),
    Description = get(description, Event),
    DesignedBy = get(designed_by, Event),
    DesignedAt = get(designed_at, Event),
    Sql = "INSERT OR REPLACE INTO designed_aggregates "
          "(aggregate_id, division_id, aggregate_name, stream_pattern, "
          "status_flags, description, designed_by, designed_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
    query_designs_store:execute(Sql, [AggregateId, DivisionId, AggregateName,
                                      StreamPattern, StatusFlags, Description,
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
