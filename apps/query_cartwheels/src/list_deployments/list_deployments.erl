%%% @doc Query: list deployments for a project
-module(list_deployments).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{cartwheel_id := CartwheelId} = Filters) ->
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Sql = "SELECT deployment_id, cartwheel_id, environment, version, notes, deployed_at "
          "FROM deployments WHERE cartwheel_id = ?1"
          " ORDER BY deployed_at DESC"
          " LIMIT ?2"
          " OFFSET ?3",

    case query_cartwheels_store:query(Sql, [CartwheelId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map({DeploymentId, CartwheelId, Environment, Version, Notes, DeployedAt}) ->
    #{
        deployment_id => DeploymentId,
        cartwheel_id => CartwheelId,
        environment => Environment,
        version => Version,
        notes => Notes,
        deployed_at => DeployedAt
    }.
