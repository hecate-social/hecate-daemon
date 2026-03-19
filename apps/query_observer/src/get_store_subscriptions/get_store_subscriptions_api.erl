%%% @doc GET /api/observer/stores/:storeId/subscriptions — List store subscriptions with lag.
-module(get_store_subscriptions_api).
-export([init/2, routes/0]).

routes() -> [{"/api/observer/stores/:store_id/subscriptions", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    StoreId = binary_to_existing_atom(cowboy_req:binding(store_id, Req0)),
    case evoq_store_inspector:list_subscriptions(StoreId) of
        {ok, Subs} ->
            hecate_api_utils:json_ok(#{items => Subs, total => length(Subs)}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, format_error(Reason), Req0)
    end.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> list_to_binary(io_lib:format("~p", [Reason])).
