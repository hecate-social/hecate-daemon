%%% @doc Projection: cartwheel_initiated_v1 -> cartwheels table
-module(cartwheel_initiated_v1_to_cartwheels).

-export([project/1]).

%% @doc Project cartwheel_initiated_v1 event to cartwheels table
-spec project(map()) -> ok | {error, term()}.
project(#{cartwheel_id := CartwheelId} = E) ->
    ContextName = maps:get(context_name, E, maps:get(name, E, undefined)),
    Sql = "INSERT OR REPLACE INTO cartwheels "
          "(cartwheel_id, torch_id, context_name, description, current_phase, status, initiated_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    query_cartwheels_store:execute(Sql, [
        CartwheelId,
        maps:get(torch_id, E, undefined),
        ContextName,
        maps:get(description, E, undefined),
        <<"discovery_n_analysis">>,
        3,  %% INITIATED | DISCOVERY_ACTIVE
        maps:get(initiated_at, E, erlang:system_time(millisecond))
    ]).
