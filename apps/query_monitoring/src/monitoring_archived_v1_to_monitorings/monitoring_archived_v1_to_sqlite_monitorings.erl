%%% @doc Projection: monitoring_archived_v1 -> monitorings table (set archived flag)
-module(monitoring_archived_v1_to_sqlite_monitorings).

-include_lib("monitor_division/include/monitoring_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    %% Set the ARCHIVED flag
    ok = query_monitoring_store:execute(
        "UPDATE monitorings SET status = status | ?1 WHERE division_id = ?2",
        [?MONITORING_ARCHIVED, DivisionId]),
    %% Recompute label
    case query_monitoring_store:query(
        "SELECT status FROM monitorings WHERE division_id = ?1", [DivisionId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?MONITORING_FLAG_MAP),
            query_monitoring_store:execute(
                "UPDATE monitorings SET status_label = ?1 WHERE division_id = ?2",
                [Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
