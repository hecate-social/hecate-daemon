%%% @doc maybe_register_connector handler
%%% Business logic for registering connectors.
%%% Computes the socket path and creates the registered event.
-module(maybe_register_connector).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

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
        command_id = generate_command_id(ConnId, Timestamp),
        command_type = register_connector,
        aggregate_type = connector_aggregate,
        aggregate_id = <<"connector-", ConnId/binary>>,
        payload = register_connector_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => connector_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_connectors_store,
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
    Default = filename:join([os:getenv("HOME"), ".config", "hecate", "connectors"]),
    application:get_env(manage_connectors, connectors_dir, list_to_binary(Default)).

generate_command_id(ConnId, Timestamp) ->
    Hash = crypto:hash(sha256, <<ConnId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
