%%% @doc add_mesh_subscription_v1 command
%%%
%%% Agent-initiated: "subscribe this daemon to the given mesh topic so
%%% inbound facts on that topic are recorded into the inbox and become
%%% queryable by my agent."
%%% @end
-module(add_mesh_subscription_v1).
-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(add_mesh_subscription_v1, {
    topic        :: binary(),
    requested_at :: integer()
}).

-opaque add_mesh_subscription_v1() :: #add_mesh_subscription_v1{}.
-export_type([add_mesh_subscription_v1/0]).

command_type() -> add_mesh_subscription_v1.

-spec new(map()) -> {ok, add_mesh_subscription_v1()} | {error, term()}.
new(#{topic := Topic, requested_at := RequestedAt})
  when is_binary(Topic), is_integer(RequestedAt) ->
    {ok, #add_mesh_subscription_v1{topic = Topic, requested_at = RequestedAt}};
new(#{topic := Topic}) when is_binary(Topic) ->
    {ok, new(Topic, erlang:system_time(millisecond))};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), integer()) -> add_mesh_subscription_v1().
new(Topic, RequestedAt) when is_binary(Topic), is_integer(RequestedAt) ->
    #add_mesh_subscription_v1{topic = Topic, requested_at = RequestedAt}.

-spec to_map(add_mesh_subscription_v1()) -> map().
to_map(#add_mesh_subscription_v1{topic = T, requested_at = R}) ->
    #{topic => T, requested_at => R}.

-spec from_map(map()) -> {ok, add_mesh_subscription_v1()} | {error, term()}.
from_map(#{topic := T, requested_at := R})
  when is_binary(T), is_integer(R) ->
    {ok, #add_mesh_subscription_v1{topic = T, requested_at = R}};
from_map(_) ->
    {error, invalid_add_mesh_subscription_command}.
