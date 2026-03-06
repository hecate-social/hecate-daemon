%%% @doc API handler: POST /api/plugins/:name/start
%%% Starts execution of an installed plugin.
-module(start_plugin_execution_api).

-export([init/2, routes/0]).

routes() -> [{"/api/plugins/:name/start", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    Name = cowboy_req:binding(name, Req0),
    PluginId = resolve_plugin_id(Name),
    case start_plugin_execution_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} -> dispatch(Cmd, Req0);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req0)
    end.

dispatch(Cmd, Req) ->
    case maybe_start_plugin_execution:dispatch(Cmd) of
        {ok, Version, _EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                plugin_id => start_plugin_execution_v1:get_plugin_id(Cmd),
                status => <<"started">>,
                version => Version
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

%% @private Resolve plugin_id from name.
%% Queries the plugins read model for the plugin_id matching the name.
%% Falls back to the name itself if not found (e.g. plugin_id = "org/name").
resolve_plugin_id(Name) ->
    Sql = "SELECT plugin_id FROM plugins WHERE name = ?1 AND (status & 2) = 0 LIMIT 1",
    case project_plugins_store:query(Sql, [Name]) of
        {ok, [[PluginId]]} -> PluginId;
        _ -> Name
    end.
