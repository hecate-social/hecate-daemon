%%% @doc register_connector_v1 command
%%% Registers a new Unix socket connector for the daemon.
-module(register_connector_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_connector_id/1, get_name/1, get_allowed_routes/1, get_metadata/1]).

-record(register_connector_v1, {
    connector_id   :: binary(),
    name           :: binary(),
    allowed_routes :: [binary()] | all,
    metadata       :: map()
}).

-export_type([register_connector_v1/0]).
-opaque register_connector_v1() :: #register_connector_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, register_connector_v1()} | {error, term()}.
new(#{connector_id := ConnId, name := Name} = Params) when
        is_binary(ConnId), is_binary(Name) ->
    Cmd = #register_connector_v1{
        connector_id = ConnId,
        name = Name,
        allowed_routes = maps:get(allowed_routes, Params, all),
        metadata = maps:get(metadata, Params, #{})
    },
    validate(Cmd);
new(_) ->
    {error, invalid_command}.

-spec validate(register_connector_v1()) -> {ok, register_connector_v1()} | {error, term()}.
validate(#register_connector_v1{connector_id = <<>>}) ->
    {error, empty_connector_id};
validate(#register_connector_v1{name = <<>>}) ->
    {error, empty_name};
validate(#register_connector_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(register_connector_v1()) -> map().
to_map(#register_connector_v1{} = Cmd) ->
    #{
        connector_id => Cmd#register_connector_v1.connector_id,
        name => Cmd#register_connector_v1.name,
        allowed_routes => Cmd#register_connector_v1.allowed_routes,
        metadata => Cmd#register_connector_v1.metadata
    }.

-spec from_map(map()) -> {ok, register_connector_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_connector_id(#register_connector_v1{connector_id = V}) -> V.
get_name(#register_connector_v1{name = V}) -> V.
get_allowed_routes(#register_connector_v1{allowed_routes = V}) -> V.
get_metadata(#register_connector_v1{metadata = V}) -> V.
