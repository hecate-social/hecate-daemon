%%% @doc Projection: plan_archived_v1 -> plans table (set archived flag)
-module(plan_archived_v1_to_sqlite_plans).

-include_lib("plan_division/include/plan_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    %% Set the ARCHIVED flag
    ok = query_plans_store:execute(
        "UPDATE plans SET status = status | ?1 WHERE division_id = ?2",
        [?PLAN_ARCHIVED, DivisionId]),
    %% Recompute label
    case query_plans_store:query(
        "SELECT status FROM plans WHERE division_id = ?1", [DivisionId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?PLAN_FLAG_MAP),
            query_plans_store:execute(
                "UPDATE plans SET status_label = ?1 WHERE division_id = ?2",
                [Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
