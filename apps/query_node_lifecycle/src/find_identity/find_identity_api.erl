%%% @doc API handler: GET /api/node/identities/:identity
-module(find_identity_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Mri = cowboy_req:binding(identity, Req0),
    case find_identity:get(Mri) of
        {ok, Identity} ->
            hecate_api_utils:json_ok(#{identity => Identity}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Identity not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
