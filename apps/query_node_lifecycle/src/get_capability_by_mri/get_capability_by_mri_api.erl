%%% @doc API handler: GET /api/node/capabilities/:mri
-module(get_capability_by_mri_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/capabilities/:mri", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Mri = cowboy_req:binding(mri, Req0),
    case get_capability_by_mri:get(Mri) of
        {ok, Capability} ->
            hecate_api_utils:json_ok(#{capability => Capability}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Capability not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
