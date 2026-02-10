%%% @doc Projection: lifecycle events (paused/resumed/completed) -> monitorings table
-module(monitoring_lifecycle_to_sqlite_monitorings).

-include_lib("monitor_division/include/monitoring_status.hrl").

-export([project_paused/1, project_resumed/1, project_completed/1]).

project_paused(Event) ->
    DivisionId = get(division_id, Event),
    PausedAt = get(paused_at, Event),
    Reason = get(reason, Event),
    update_status_flags(DivisionId, [{set, ?MONITORING_PAUSED}, {unset, ?MONITORING_ACTIVE}]),
    query_monitoring_store:execute(
        "UPDATE monitorings SET paused_at = ?1, pause_reason = ?2 WHERE division_id = ?3",
        [PausedAt, Reason, DivisionId]).

project_resumed(Event) ->
    DivisionId = get(division_id, Event),
    update_status_flags(DivisionId, [{set, ?MONITORING_ACTIVE}, {unset, ?MONITORING_PAUSED}]),
    query_monitoring_store:execute(
        "UPDATE monitorings SET paused_at = NULL, pause_reason = NULL WHERE division_id = ?1",
        [DivisionId]).

project_completed(Event) ->
    DivisionId = get(division_id, Event),
    CompletedAt = get(completed_at, Event),
    update_status_flags(DivisionId, [{set, ?MONITORING_COMPLETED}, {unset, ?MONITORING_ACTIVE}]),
    query_monitoring_store:execute(
        "UPDATE monitorings SET completed_at = ?1 WHERE division_id = ?2",
        [CompletedAt, DivisionId]).

%% Internal

update_status_flags(DivisionId, Ops) ->
    case query_monitoring_store:query(
        "SELECT status FROM monitorings WHERE division_id = ?1", [DivisionId]) of
        {ok, [{CurrentStatus}]} ->
            NewStatus = lists:foldl(fun
                ({set, Flag}, S) -> evoq_bit_flags:set(S, Flag);
                ({unset, Flag}, S) -> evoq_bit_flags:unset(S, Flag)
            end, CurrentStatus, Ops),
            Label = evoq_bit_flags:to_string(NewStatus, ?MONITORING_FLAG_MAP),
            query_monitoring_store:execute(
                "UPDATE monitorings SET status = ?1, status_label = ?2 WHERE division_id = ?3",
                [NewStatus, Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
