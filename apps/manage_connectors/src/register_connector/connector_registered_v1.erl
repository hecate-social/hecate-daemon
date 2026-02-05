%%% @doc connector_registered_v1 event
%%% Emitted when a connector is successfully registered.
-module(connector_registered_v1).

-export([new/4, to_map/1, from_map/1]).
-export([get_connector_id/1, get_name/1, get_socket_path/1,
         get_allowed_routes/1, get_metadata/1, get_registered_at/1]).

-record(connector_registered_v1, {
    connector_id   :: binary(),
    name           :: binary(),
    socket_path    :: binary(),
    allowed_routes :: [binary()] | all,
    metadata       :: map(),
    registered_at  :: integer()
}).

-export_type([connector_registered_v1/0]).
-opaque connector_registered_v1() :: #connector_registered_v1{}.

-spec new(binary(), binary(), binary(), [binary()] | all) -> connector_registered_v1().
new(ConnId, Name, SocketPath, AllowedRoutes) ->
    #connector_registered_v1{
        connector_id = ConnId,
        name = Name,
        socket_path = SocketPath,
        allowed_routes = AllowedRoutes,
        metadata = #{},
        registered_at = erlang:system_time(millisecond)
    }.

-spec to_map(connector_registered_v1()) -> map().
to_map(#connector_registered_v1{} = E) ->
    #{
        event_type => <<"connector_registered_v1">>,
        connector_id => E#connector_registered_v1.connector_id,
        name => E#connector_registered_v1.name,
        socket_path => E#connector_registered_v1.socket_path,
        allowed_routes => E#connector_registered_v1.allowed_routes,
        metadata => E#connector_registered_v1.metadata,
        registered_at => E#connector_registered_v1.registered_at
    }.

-spec from_map(map()) -> {ok, connector_registered_v1()} | {error, term()}.
from_map(#{
    connector_id := ConnId,
    name := Name,
    socket_path := SocketPath,
    registered_at := At
} = Map) ->
    {ok, #connector_registered_v1{
        connector_id = ConnId,
        name = Name,
        socket_path = SocketPath,
        allowed_routes = maps:get(allowed_routes, Map, all),
        metadata = maps:get(metadata, Map, #{}),
        registered_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

get_connector_id(#connector_registered_v1{connector_id = V}) -> V.
get_name(#connector_registered_v1{name = V}) -> V.
get_socket_path(#connector_registered_v1{socket_path = V}) -> V.
get_allowed_routes(#connector_registered_v1{allowed_routes = V}) -> V.
get_metadata(#connector_registered_v1{metadata = V}) -> V.
get_registered_at(#connector_registered_v1{registered_at = V}) -> V.
