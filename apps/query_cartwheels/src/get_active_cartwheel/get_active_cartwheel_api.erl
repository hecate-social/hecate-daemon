%%% @doc API handler: GET /api/cartwheel
%%%
%%% Get the active cartwheel from the current torch.
%%% @end
-module(get_active_cartwheel_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case get_active_torch_cartwheel() of
        {ok, Cartwheel} ->
            hecate_api_utils:json_ok(#{cartwheel => Cartwheel}, Req0);
        none ->
            hecate_api_utils:json_ok(#{cartwheel => null}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

get_active_torch_cartwheel() ->
    case get_torches_page:execute(#{limit => 1}) of
        {ok, [#{active_cartwheel_id := Id}]} when Id =/= undefined, Id =/= null ->
            get_cartwheel_by_id:execute(Id);
        {ok, _} ->
            none;
        {error, _} = E ->
            E
    end.
