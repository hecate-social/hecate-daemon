%%% @doc Projection: rescue_archived_v1 -> rescues table (set archived flag)
-module(rescue_archived_v1_to_sqlite_rescues).

-include_lib("rescue_division/include/rescue_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    %% Set the ARCHIVED flag
    ok = query_rescues_store:execute(
        "UPDATE rescues SET status = status | ?1 WHERE division_id = ?2",
        [?RESCUE_ARCHIVED, DivisionId]),
    %% Recompute label
    case query_rescues_store:query(
        "SELECT status FROM rescues WHERE division_id = ?1", [DivisionId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?RESCUE_FLAG_MAP),
            query_rescues_store:execute(
                "UPDATE rescues SET status_label = ?1 WHERE division_id = ?2",
                [Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
