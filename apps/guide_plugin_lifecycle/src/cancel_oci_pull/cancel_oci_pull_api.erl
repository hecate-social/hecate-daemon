%%% @doc API handler: POST /api/appstore/plugins/:id/cancel-pull
%%%
%%% Cancels an in-progress OCI image pull.
%%% @end
-module(cancel_oci_pull_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/plugins/:id/cancel-pull", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    PluginId = cowboy_req:binding(id, Req0),
    case cancel_oci_pull_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_cancel_oci_pull:dispatch(Cmd) of
                {ok, _, _} ->
                    hecate_api_utils:json_ok(200, #{ok => true, plugin_id => PluginId}, Req0);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req0)
    end.
