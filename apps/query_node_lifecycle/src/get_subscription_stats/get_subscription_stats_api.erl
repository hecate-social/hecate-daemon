%%% @doc API handler: GET /api/node/subscriptions/stats
-module(get_subscription_stats_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/subscriptions/stats", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case get_subscription_stats:get() of
        {ok, Stats} ->
            hecate_api_utils:json_ok(Stats, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
