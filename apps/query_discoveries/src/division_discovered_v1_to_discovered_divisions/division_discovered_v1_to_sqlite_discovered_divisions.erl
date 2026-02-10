%%% @doc Projection: division_discovered_v1 -> discovered_divisions table
-module(division_discovered_v1_to_sqlite_discovered_divisions).
-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    VentureId = get(venture_id, Event),
    ContextName = get(context_name, Event),
    Description = get(description, Event),
    IdentifiedBy = get(identified_by, Event),
    DiscoveredAt = get(discovered_at, Event),
    Sql = "INSERT OR REPLACE INTO discovered_divisions "
          "(division_id, venture_id, context_name, description, identified_by, discovered_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_discoveries_store:execute(Sql, [DivisionId, VentureId, ContextName, Description,
                                          IdentifiedBy, DiscoveredAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
