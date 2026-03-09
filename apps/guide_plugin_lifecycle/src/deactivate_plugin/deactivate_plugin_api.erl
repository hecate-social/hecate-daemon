%%% @doc API handler: POST /api/plugins/deactivate
%%% Deactivates an in-VM plugin (unloads code from the BEAM).
%%% Requires plugin_id in POST body.
-module(deactivate_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/plugins/deactivate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            case hecate_api_utils:get_field(plugin_id, Body) of
                undefined ->
                    hecate_api_utils:bad_request(<<"plugin_id is required">>, Req1);
                PluginId ->
                    do_deactivate(PluginId, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_deactivate(PluginId, Req) ->
    case deactivate_plugin_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_deactivate_plugin:dispatch(Cmd) of
        {ok, Version, _EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                plugin_id => deactivate_plugin_v1:get_plugin_id(Cmd),
                status => <<"deactivated">>,
                version => Version
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
