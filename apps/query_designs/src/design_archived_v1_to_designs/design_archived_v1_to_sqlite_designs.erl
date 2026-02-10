%%% @doc Projection: design_archived_v1 -> designs table (set archived flag)
-module(design_archived_v1_to_sqlite_designs).

-include_lib("design_division/include/design_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    %% Set the ARCHIVED flag
    ok = query_designs_store:execute(
        "UPDATE designs SET status = status | ?1 WHERE division_id = ?2",
        [?DESIGN_ARCHIVED, DivisionId]),
    %% Recompute label
    case query_designs_store:query(
        "SELECT status FROM designs WHERE division_id = ?1", [DivisionId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?DESIGN_FLAG_MAP),
            query_designs_store:execute(
                "UPDATE designs SET status_label = ?1 WHERE division_id = ?2",
                [Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
