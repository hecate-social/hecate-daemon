%%% @doc Projection: discovery_archived_v1 -> discoveries table (set archived flag)
-module(discovery_archived_v1_to_sqlite_discoveries).

-include_lib("discover_divisions/include/discovery_status.hrl").

-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    %% Set the ARCHIVED flag
    ok = query_discoveries_store:execute(
        "UPDATE discoveries SET status = status | ?1 WHERE venture_id = ?2",
        [?DISCOVERY_ARCHIVED, VentureId]),
    %% Recompute label
    case query_discoveries_store:query(
        "SELECT status FROM discoveries WHERE venture_id = ?1", [VentureId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?DISCOVERY_FLAG_MAP),
            query_discoveries_store:execute(
                "UPDATE discoveries SET status_label = ?1 WHERE venture_id = ?2",
                [Label, VentureId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
