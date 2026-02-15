%%% @doc Projection: fact_arrow_drawn_v1 -> fact_arrows table
-module(fact_arrow_drawn_v1_to_sqlite_fact_arrows).
-export([project/1]).

project(Event) ->
    ArrowId = get(arrow_id, Event),
    VentureId = get(venture_id, Event),
    StormNumber = get(storm_number, Event, 0),
    FromCluster = get(from_cluster, Event),
    ToCluster = get(to_cluster, Event),
    FactName = get(fact_name, Event),
    CreatedAt = get(drawn_at, Event, erlang:system_time(millisecond)),
    logger:info("[PROJECTION] ~s: projecting arrow ~s", [?MODULE, ArrowId]),
    Sql = "INSERT INTO fact_arrows "
          "(arrow_id, venture_id, storm_number, from_cluster, to_cluster, fact_name, created_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    query_venture_lifecycle_store:execute(Sql, [
        ArrowId, VentureId, StormNumber, FromCluster, ToCluster, FactName, CreatedAt
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
