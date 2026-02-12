%%% @doc suspend_connector_v1 command
%%% Temporarily suspends a connector (stops listener but keeps state).
-module(suspend_connector_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_connector_id/1, get_reason/1]).

-record(suspend_connector_v1, {
    connector_id :: binary(),
    reason       :: binary()
}).

-export_type([suspend_connector_v1/0]).
-opaque suspend_connector_v1() :: #suspend_connector_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, suspend_connector_v1()} | {error, term()}.
new(#{connector_id := ConnId} = Params) when is_binary(ConnId), ConnId =/= <<>> ->
    {ok, #suspend_connector_v1{
        connector_id = ConnId,
        reason = maps:get(reason, Params, <<"manual_suspension">>)
    }};
new(_) ->
    {error, invalid_command}.

-spec validate(suspend_connector_v1()) -> {ok, suspend_connector_v1()} | {error, term()}.
validate(#suspend_connector_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(suspend_connector_v1()) -> map().
to_map(#suspend_connector_v1{connector_id = ConnId, reason = Reason}) ->
    #{
        command_type => <<"suspend_connector">>,
        connector_id => ConnId,
        reason => Reason
    }.

-spec from_map(map()) -> {ok, suspend_connector_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_connector_id(#suspend_connector_v1{connector_id = V}) -> V.
get_reason(#suspend_connector_v1{reason = V}) -> V.
