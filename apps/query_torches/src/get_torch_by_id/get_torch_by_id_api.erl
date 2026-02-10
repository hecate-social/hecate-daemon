%%% @doc API handler: GET /api/torches/:torch_id
%%%
%%% Get a specific torch by ID.
%%% Lives in the get_torch_by_id query spoke for vertical slicing.
%%% @end
-module(get_torch_by_id_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    TorchId = cowboy_req:binding(torch_id, Req0),
    case get_torch_by_id:execute(TorchId) of
        {ok, Torch} ->
            hecate_api_utils:json_ok(#{torch => Torch}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Torch not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
