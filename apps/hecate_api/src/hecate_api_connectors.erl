%%% @doc REST handler for connector management endpoints.
%%%
%%% POST /connectors/register  — Register a new connector
%%% GET  /connectors           — List registered connectors (basic, from event replay)
%%% GET  /connectors/:id       — Get connector info
%%% POST /connectors/:id/revoke — Revoke a connector
-module(hecate_api_connectors).

-export([init/2]).

init(Req0, [register]) ->
    handle_register(Req0);
init(Req0, [list]) ->
    handle_list(Req0);
init(Req0, [get]) ->
    handle_get(Req0);
init(Req0, [revoke]) ->
    handle_revoke(Req0).

%% POST /connectors/register
handle_register(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),

    ConnId = maps:get(<<"connector_id">>, Params, undefined),
    Name = maps:get(<<"name">>, Params, undefined),
    AllowedRoutesRaw = maps:get(<<"allowed_routes">>, Params, <<"all">>),

    AllowedRoutes = case AllowedRoutesRaw of
        <<"all">> -> all;
        Routes when is_list(Routes) -> Routes;
        _ -> all
    end,

    CmdParams = #{
        connector_id => ConnId,
        name => Name,
        allowed_routes => AllowedRoutes,
        metadata => maps:get(<<"metadata">>, Params, #{})
    },

    case register_connector_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_register_connector:dispatch(Cmd) of
                {ok, Version, Events} ->
                    Response = json:encode(#{
                        ok => true,
                        version => Version,
                        events => Events,
                        connector_id => ConnId
                    }),
                    Req = cowboy_req:reply(201,
                        #{<<"content-type">> => <<"application/json">>},
                        Response, Req1),
                    {ok, Req, []};
                {error, Reason} ->
                    error_response(Req1, 400, Reason)
            end;
        {error, Reason} ->
            error_response(Req1, 400, Reason)
    end.

%% GET /connectors
handle_list(Req0) ->
    %% Return list of known connectors from the PM's active listeners
    %% For a full implementation, use a query service with projections.
    %% This is a lightweight approach reading from the process manager state.
    Response = json:encode(#{
        ok => true,
        connectors => [],
        message => <<"Use query_connectors service for full listing">>
    }),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req0),
    {ok, Req, []}.

%% GET /connectors/:connector_id
handle_get(Req0) ->
    ConnId = cowboy_req:binding(connector_id, Req0),
    %% Check if socket file exists as a quick status check
    ConnectorsDir = connectors_dir(),
    SocketPath = filename:join([ConnectorsDir, <<ConnId/binary, ".sock">>]),
    SocketExists = filelib:is_file(SocketPath),

    Response = json:encode(#{
        ok => true,
        connector_id => ConnId,
        socket_path => SocketPath,
        socket_exists => SocketExists
    }),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req0),
    {ok, Req, []}.

%% POST /connectors/:connector_id/revoke
handle_revoke(Req0) ->
    ConnId = cowboy_req:binding(connector_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = case Body of
        <<>> -> #{};
        _ -> json:decode(Body)
    end,

    CmdParams = #{
        connector_id => ConnId,
        reason => maps:get(<<"reason">>, Params, <<"manual_revocation">>)
    },

    case revoke_connector_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_revoke_connector:dispatch(Cmd) of
                {ok, Version, Events} ->
                    Response = json:encode(#{
                        ok => true,
                        version => Version,
                        events => Events,
                        connector_id => ConnId
                    }),
                    Req = cowboy_req:reply(200,
                        #{<<"content-type">> => <<"application/json">>},
                        Response, Req1),
                    {ok, Req, []};
                {error, Reason} ->
                    error_response(Req1, 400, Reason)
            end;
        {error, Reason} ->
            error_response(Req1, 400, Reason)
    end.

%% Internal

error_response(Req, StatusCode, Reason) when is_atom(Reason) ->
    error_response(Req, StatusCode, atom_to_binary(Reason, utf8));
error_response(Req, StatusCode, Reason) ->
    Response = json:encode(#{
        ok => false,
        error => Reason
    }),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req),
    {ok, Req2, []}.

connectors_dir() ->
    Default = filename:join([os:getenv("HOME"), ".config", "hecate", "connectors"]),
    application:get_env(manage_connectors, connectors_dir, list_to_binary(Default)).
