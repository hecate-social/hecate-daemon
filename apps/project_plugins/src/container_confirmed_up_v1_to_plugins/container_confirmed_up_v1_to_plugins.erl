%%% @doc Projection: container_confirmed_up_v1 -> plugins ETS read model.
%%% Sets CONFIRMED_UP(16), clears CONFIRMED_DOWN(32) and PULLING(64).
-module(container_confirmed_up_v1_to_plugins).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, plugins).

interested_in() -> [<<"container_confirmed_up_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            Updated = Plugin#{
                status       => (S bor 16) band (bnot 32) band (bnot 64),
                status_label => <<"Running">>
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
