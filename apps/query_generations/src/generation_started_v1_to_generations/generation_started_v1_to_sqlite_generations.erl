%%% @doc Projection: generation_started_v1 -> generations table
-module(generation_started_v1_to_sqlite_generations).

-include_lib("generate_division/include/generation_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    StartedAt = get(started_at, Event),
    StartedBy = get(started_by, Event),
    Status = evoq_bit_flags:set(evoq_bit_flags:set(0, ?GENERATION_INITIATED), ?GENERATION_ACTIVE),
    StatusLabel = evoq_bit_flags:to_string(Status, ?GENERATION_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO generations "
          "(division_id, status, status_label, started_at, started_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_generations_store:execute(Sql, [DivisionId, Status, StatusLabel, StartedAt, StartedBy]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
