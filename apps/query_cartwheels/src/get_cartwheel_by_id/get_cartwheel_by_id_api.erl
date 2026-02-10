%%% @doc API handler: GET /api/cartwheels/:cartwheel_id
%%%
%%% Get a specific cartwheel by ID.
%%% @end
-module(get_cartwheel_by_id_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    case get_cartwheel_by_id:execute(CartwheelId) of
        {ok, Cartwheel} ->
            hecate_api_utils:json_ok(#{cartwheel => Cartwheel}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Cartwheel not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
