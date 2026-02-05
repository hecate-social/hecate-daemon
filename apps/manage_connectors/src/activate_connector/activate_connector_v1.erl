%%% @doc activate_connector_v1 command
%%% Re-activates a suspended connector.
-module(activate_connector_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_connector_id/1]).

-record(activate_connector_v1, {
    connector_id :: binary()
}).

-export_type([activate_connector_v1/0]).
-opaque activate_connector_v1() :: #activate_connector_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, activate_connector_v1()} | {error, term()}.
new(#{connector_id := ConnId}) when is_binary(ConnId), ConnId =/= <<>> ->
    {ok, #activate_connector_v1{connector_id = ConnId}};
new(_) ->
    {error, invalid_command}.

-spec validate(activate_connector_v1()) -> {ok, activate_connector_v1()} | {error, term()}.
validate(#activate_connector_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(activate_connector_v1()) -> map().
to_map(#activate_connector_v1{connector_id = ConnId}) ->
    #{
        command_type => <<"activate_connector">>,
        connector_id => ConnId
    }.

-spec from_map(map()) -> {ok, activate_connector_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_connector_id(#activate_connector_v1{connector_id = V}) -> V.
