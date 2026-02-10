%%% @doc Projection: generation_archived_v1 -> generations table (set archived flag)
-module(generation_archived_v1_to_sqlite_generations).

-include_lib("generate_division/include/generation_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    %% Set the ARCHIVED flag
    ok = query_generations_store:execute(
        "UPDATE generations SET status = status | ?1 WHERE division_id = ?2",
        [?GENERATION_ARCHIVED, DivisionId]),
    %% Recompute label
    case query_generations_store:query(
        "SELECT status FROM generations WHERE division_id = ?1", [DivisionId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?GENERATION_FLAG_MAP),
            query_generations_store:execute(
                "UPDATE generations SET status_label = ?1 WHERE division_id = ?2",
                [Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
