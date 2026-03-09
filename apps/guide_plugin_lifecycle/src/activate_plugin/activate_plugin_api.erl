%%% @doc API handler: POST /api/plugins/activate
%%% Activates an in-VM plugin by loading its code into the VM.
%%% Requires plugin_id and callback_module in POST body.
-module(activate_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/plugins/activate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            PluginId = hecate_api_utils:get_field(plugin_id, Body),
            CallbackModule = hecate_api_utils:get_field(callback_module, Body),
            case validate(PluginId, CallbackModule) of
                ok -> do_activate(PluginId, CallbackModule, Req1);
                {error, Reason} -> hecate_api_utils:bad_request(Reason, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

validate(undefined, _) -> {error, <<"plugin_id is required">>};
validate(_, undefined) -> {error, <<"callback_module is required">>};
validate(_, _) -> ok.

do_activate(PluginId, CallbackModule, Req) ->
    case activate_plugin_v1:new(#{plugin_id => PluginId, callback_module => CallbackModule}) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_activate_plugin:dispatch(Cmd) of
        {ok, Version, _EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                plugin_id => activate_plugin_v1:get_plugin_id(Cmd),
                callback_module => activate_plugin_v1:get_callback_module(Cmd),
                status => <<"activated">>,
                version => Version
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
