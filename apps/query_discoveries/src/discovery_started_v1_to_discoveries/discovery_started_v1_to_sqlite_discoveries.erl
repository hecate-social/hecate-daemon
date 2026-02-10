%%% @doc Projection: discovery_started_v1 -> discoveries table
-module(discovery_started_v1_to_sqlite_discoveries).

-include_lib("discover_divisions/include/discovery_status.hrl").

-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    StartedAt = get(started_at, Event),
    StartedBy = get(started_by, Event),
    Status = evoq_bit_flags:set(evoq_bit_flags:set(0, ?DISCOVERY_INITIATED), ?DISCOVERY_ACTIVE),
    StatusLabel = evoq_bit_flags:to_string(Status, ?DISCOVERY_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO discoveries "
          "(venture_id, status, status_label, started_at, started_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_discoveries_store:execute(Sql, [VentureId, Status, StatusLabel, StartedAt, StartedBy]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
