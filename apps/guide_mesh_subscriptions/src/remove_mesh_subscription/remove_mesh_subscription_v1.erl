%%% @doc remove_mesh_subscription_v1 command
%%%
%%% Agent-initiated: "unsubscribe this daemon from the given mesh topic."
%%% @end
-module(remove_mesh_subscription_v1).
-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(remove_mesh_subscription_v1, {
    topic        :: binary(),
    requested_at :: integer()
}).

-opaque remove_mesh_subscription_v1() :: #remove_mesh_subscription_v1{}.
-export_type([remove_mesh_subscription_v1/0]).

command_type() -> remove_mesh_subscription_v1.

-spec new(map()) -> {ok, remove_mesh_subscription_v1()} | {error, term()}.
new(#{topic := Topic, requested_at := RequestedAt})
  when is_binary(Topic), is_integer(RequestedAt) ->
    {ok, #remove_mesh_subscription_v1{topic = Topic, requested_at = RequestedAt}};
new(#{topic := Topic}) when is_binary(Topic) ->
    {ok, new(Topic, erlang:system_time(millisecond))};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), integer()) -> remove_mesh_subscription_v1().
new(Topic, RequestedAt) when is_binary(Topic), is_integer(RequestedAt) ->
    #remove_mesh_subscription_v1{topic = Topic, requested_at = RequestedAt}.

-spec to_map(remove_mesh_subscription_v1()) -> map().
to_map(#remove_mesh_subscription_v1{topic = T, requested_at = R}) ->
    #{topic => T, requested_at => R}.

-spec from_map(map()) -> {ok, remove_mesh_subscription_v1()} | {error, term()}.
from_map(#{topic := T, requested_at := R})
  when is_binary(T), is_integer(R) ->
    {ok, #remove_mesh_subscription_v1{topic = T, requested_at = R}};
from_map(_) ->
    {error, invalid_remove_mesh_subscription_command}.
