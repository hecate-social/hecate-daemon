-module(get_mentor_subscriptions_page_api).
-export([init/2, routes/0]).

routes() -> [{"/api/mentors/subscriptions", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    SubscriberId = hecate_identity:agent_id(),
    case get_mentor_subscriptions_page:execute(SubscriberId) of
        {ok, Subs} ->
            hecate_api_utils:json_ok(#{subscriptions => Subs}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
