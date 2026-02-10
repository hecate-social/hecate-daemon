%%% @doc Projection: deployment_archived_v1 -> deployments table (set archived flag)
-module(deployment_archived_v1_to_sqlite_deployments).

-include_lib("deploy_division/include/deployment_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    %% Set the ARCHIVED flag
    ok = query_deployments_store:execute(
        "UPDATE deployments SET status = status | ?1 WHERE division_id = ?2",
        [?DEPLOYMENT_ARCHIVED, DivisionId]),
    %% Recompute label
    case query_deployments_store:query(
        "SELECT status FROM deployments WHERE division_id = ?1", [DivisionId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?DEPLOYMENT_FLAG_MAP),
            query_deployments_store:execute(
                "UPDATE deployments SET status_label = ?1 WHERE division_id = ?2",
                [Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
