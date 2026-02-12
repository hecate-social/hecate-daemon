%%% @doc Projection: discovery_completed_v1 -> ventures table
%%% Unsets DISCOVERING flag, sets DISCOVERY_COMPLETED flag.
-module(discovery_completed_v1_to_sqlite_ventures).

-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").

-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, VentureId]),
    %% Unset DISCOVERING (8), set DISCOVERY_COMPLETED (32)
    %% SQL: status = (status & ~8) | 32
    ok = query_venture_lifecycle_store:execute(
        "UPDATE ventures SET status = (status & ~?1) | ?2 WHERE venture_id = ?3",
        [?VL_DISCOVERING, ?VL_DISCOVERY_COMPLETED, VentureId]),
    %% Recompute label
    case query_venture_lifecycle_store:query(
        "SELECT status FROM ventures WHERE venture_id = ?1", [VentureId]) of
        {ok, [[NewStatus]]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?VL_FLAG_MAP),
            query_venture_lifecycle_store:execute(
                "UPDATE ventures SET status_label = ?1 WHERE venture_id = ?2",
                [Label, VentureId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
