%%% @doc Projection: lifecycle events (paused/resumed/completed) -> discoveries table
-module(discovery_lifecycle_to_sqlite_discoveries).

-include_lib("discover_divisions/include/discovery_status.hrl").

-export([project_paused/1, project_resumed/1, project_completed/1]).

project_paused(Event) ->
    VentureId = get(venture_id, Event),
    PausedAt = get(paused_at, Event),
    Reason = get(reason, Event),
    update_status_flags(VentureId, [{set, ?DISCOVERY_PAUSED}, {unset, ?DISCOVERY_ACTIVE}]),
    query_discoveries_store:execute(
        "UPDATE discoveries SET paused_at = ?1, pause_reason = ?2 WHERE venture_id = ?3",
        [PausedAt, Reason, VentureId]).

project_resumed(Event) ->
    VentureId = get(venture_id, Event),
    update_status_flags(VentureId, [{set, ?DISCOVERY_ACTIVE}, {unset, ?DISCOVERY_PAUSED}]),
    query_discoveries_store:execute(
        "UPDATE discoveries SET paused_at = NULL, pause_reason = NULL WHERE venture_id = ?1",
        [VentureId]).

project_completed(Event) ->
    VentureId = get(venture_id, Event),
    CompletedAt = get(completed_at, Event),
    update_status_flags(VentureId, [{set, ?DISCOVERY_COMPLETED}, {unset, ?DISCOVERY_ACTIVE}]),
    query_discoveries_store:execute(
        "UPDATE discoveries SET completed_at = ?1 WHERE venture_id = ?2",
        [CompletedAt, VentureId]).

%% Internal

update_status_flags(VentureId, Ops) ->
    case query_discoveries_store:query(
        "SELECT status FROM discoveries WHERE venture_id = ?1", [VentureId]) of
        {ok, [{CurrentStatus}]} ->
            NewStatus = lists:foldl(fun
                ({set, Flag}, S) -> evoq_bit_flags:set(S, Flag);
                ({unset, Flag}, S) -> evoq_bit_flags:unset(S, Flag)
            end, CurrentStatus, Ops),
            Label = evoq_bit_flags:to_string(NewStatus, ?DISCOVERY_FLAG_MAP),
            query_discoveries_store:execute(
                "UPDATE discoveries SET status = ?1, status_label = ?2 WHERE venture_id = ?3",
                [NewStatus, Label, VentureId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
