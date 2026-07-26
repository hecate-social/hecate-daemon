%%% @doc GET /api/mesh/subscriptions
%%%
%%% Returns the current subscription roster as projected from
%%% `mesh_subscriptions_store' into the `mesh_subscriptions' ETS table
%%% by `mesh_subscriptions_lifecycle_to_subscription_list'.
%%%
%%% Response:
%%%   #{ok => true,
%%%     subscriptions => [
%%%       #{topic => <<...>>, subscribed_at => N, fact_id => <<...>>},
%%%       ...
%%%     ]}
%%% @end
-module(get_mesh_subscriptions_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/subscriptions/list", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    {ok, Subs} = project_mesh_activity_store:list_subscriptions(),
    hecate_api_utils:json_ok(#{subscriptions => Subs}, Req0).
