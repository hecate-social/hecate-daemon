%%% @doc revoke_connector_v1 command
%%% Permanently revokes a connector's access to the daemon.
-module(revoke_connector_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_connector_id/1, get_reason/1]).

-record(revoke_connector_v1, {
    connector_id :: binary(),
    reason       :: binary()
}).

-export_type([revoke_connector_v1/0]).
-opaque revoke_connector_v1() :: #revoke_connector_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, revoke_connector_v1()} | {error, term()}.
new(#{connector_id := ConnId} = Params) when is_binary(ConnId) ->
    Cmd = #revoke_connector_v1{
        connector_id = ConnId,
        reason = maps:get(reason, Params, <<"manual_revocation">>)
    },
    validate(Cmd);
new(_) ->
    {error, invalid_command}.

-spec validate(revoke_connector_v1()) -> {ok, revoke_connector_v1()} | {error, term()}.
validate(#revoke_connector_v1{connector_id = <<>>}) ->
    {error, empty_connector_id};
validate(#revoke_connector_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(revoke_connector_v1()) -> map().
to_map(#revoke_connector_v1{} = Cmd) ->
    #{
        command_type => <<"revoke_connector">>,
        connector_id => Cmd#revoke_connector_v1.connector_id,
        reason => Cmd#revoke_connector_v1.reason
    }.

-spec from_map(map()) -> {ok, revoke_connector_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_connector_id(#revoke_connector_v1{connector_id = V}) -> V.
get_reason(#revoke_connector_v1{reason = V}) -> V.
