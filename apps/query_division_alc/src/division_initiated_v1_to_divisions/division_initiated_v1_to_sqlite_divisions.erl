%%% @doc Projection: division_initiated_v1 -> divisions table
-module(division_initiated_v1_to_sqlite_divisions).

-include_lib("guide_division_alc/include/division_alc_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    VentureId = get(venture_id, Event),
    ContextName = get(context_name, Event),
    InitiatedAt = get(initiated_at, Event),
    InitiatedBy = get(initiated_by, Event),
    OverallStatus = ?DA_INITIATED,
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, DivisionId]),
    Sql = "INSERT OR REPLACE INTO divisions "
          "(division_id, venture_id, context_name, overall_status, "
          "dna_status, anp_status, tni_status, dno_status, "
          "initiated_at, initiated_by) "
          "VALUES (?1, ?2, ?3, ?4, 0, 0, 0, 0, ?5, ?6)",
    query_division_alc_store:execute(Sql, [DivisionId, VentureId, ContextName,
                                           OverallStatus, InitiatedAt, InitiatedBy]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
