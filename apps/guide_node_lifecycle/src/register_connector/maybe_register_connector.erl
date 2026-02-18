%%% @doc maybe_register_connector handler
%%% Business logic for registering connectors.
%%% Computes the socket path and creates the registered event.
-module(maybe_register_connector).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle_from_map/1, dispatch/1]).


%% @doc Handle register_connector from a plain map payload.
-spec handle_from_map(map()) -> {ok, [connector_registered_v1:connector_registered_v1()]} | {error, term()}.
handle_from_map(#{connector_id := _ConnId, name := _Name} = Payload) ->
    case register_connector_v1:new(Payload) of
        {ok, Cmd} -> handle(Cmd);
        {error, Reason} -> {error, Reason}
    end.

%% @doc Handle register_connector_v1 command (business logic).
%% Computes socket path from connector ID and connectors directory.
-spec handle(register_connector_v1:register_connector_v1()) ->
    {ok, [connector_registered_v1:connector_registered_v1()]} | {error, term()}.
handle(Cmd) ->
    ConnId = register_connector_v1:get_connector_id(Cmd),
    Name = register_connector_v1:get_name(Cmd),
    AllowedRoutes = register_connector_v1:get_allowed_routes(Cmd),
    SocketPath = compute_socket_path(ConnId),
    Event = connector_registered_v1:new(ConnId, Name, SocketPath, AllowedRoutes),
    {ok, [Event]}.

%% @doc Dispatch command via evoq.
-spec dispatch(register_connector_v1:register_connector_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ConnId = register_connector_v1:get_connector_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = register_connector,
        aggregate_type = node_aggregate,
        aggregate_id = <<"connector-", ConnId/binary>>,
        payload = register_connector_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp}
    },

    Opts = #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% @private Compute the socket file path for a connector.
compute_socket_path(ConnectorId) ->
    ConnectorsDir = connectors_dir(),
    SocketFile = <<ConnectorId/binary, ".sock">>,
    filename:join([ConnectorsDir, SocketFile]).

connectors_dir() ->
    application:get_env(guide_node_lifecycle, connectors_dir,
                        list_to_binary(shared_paths:connectors_dir())).
