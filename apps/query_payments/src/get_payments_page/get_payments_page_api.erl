%%% @doc API handler: GET /api/appstore/payments
%%%
%%% Returns all payments for the current user (consumer).
%%% @end
-module(get_payments_page_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/payments", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            hecate_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        ConsumerId ->
            case project_payments_store:list_payments(ConsumerId) of
                {ok, Items} ->
                    hecate_api_utils:json_ok(#{items => Items}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.
