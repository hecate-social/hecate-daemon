-module(get_connector_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    ConnId = cowboy_req:binding(connector_id, Req0),
    ConnectorsDir = connectors_dir(),
    SocketPath = filename:join([ConnectorsDir, <<ConnId/binary, ".sock">>]),
    SocketExists = filelib:is_file(SocketPath),
    hecate_api_utils:json_ok(#{
        connector_id => ConnId,
        socket_path => SocketPath,
        socket_exists => SocketExists
    }, Req0).

connectors_dir() ->
    Default = filename:join([os:getenv("HOME"), ".config", "hecate", "connectors"]),
    application:get_env(manage_connectors, connectors_dir, list_to_binary(Default)).
