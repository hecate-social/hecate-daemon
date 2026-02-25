%%% @doc API handler: POST /api/node/plugins/remove
%%%
%%% Removes an installed plugin from this node.
%%% Lives in the remove_plugin desk for vertical slicing.
%%% @end
-module(remove_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/node/plugins/remove", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_remove(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_remove(Params, Req) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Params),
    case PluginId of
        undefined -> hecate_api_utils:bad_request(<<"plugin_id is required">>, Req);
        _ -> create_and_dispatch(PluginId, Req)
    end.

create_and_dispatch(PluginId, Req) ->
    CmdParams = #{plugin_id => PluginId},
    case remove_plugin_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_remove_plugin:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                plugin_id => remove_plugin_v1:get_plugin_id(Cmd),
                version   => Version,
                events    => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
