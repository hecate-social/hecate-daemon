%%% @doc publish_mesh_fact_v1 command
%%%
%%% Agent-initiated: "publish this fact on this realm-scoped mesh topic."
%%% @end
-module(publish_mesh_fact_v1).
-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).

-record(publish_mesh_fact_v1, {
    topic        :: binary(),
    fact         :: map(),
    requested_at :: integer()
}).

-opaque publish_mesh_fact_v1() :: #publish_mesh_fact_v1{}.
-export_type([publish_mesh_fact_v1/0]).

command_type() -> publish_mesh_fact_v1.

-spec new(map()) -> {ok, publish_mesh_fact_v1()} | {error, term()}.
new(#{topic := Topic, fact := Fact, requested_at := RequestedAt})
  when is_binary(Topic), is_map(Fact), is_integer(RequestedAt) ->
    {ok, #publish_mesh_fact_v1{topic = Topic, fact = Fact, requested_at = RequestedAt}};
new(#{topic := Topic, fact := Fact}) when is_binary(Topic), is_map(Fact) ->
    {ok, new(Topic, Fact, erlang:system_time(millisecond))};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), map(), integer()) -> publish_mesh_fact_v1().
new(Topic, Fact, RequestedAt) when is_binary(Topic), is_map(Fact), is_integer(RequestedAt) ->
    #publish_mesh_fact_v1{topic = Topic, fact = Fact, requested_at = RequestedAt}.

-spec to_map(publish_mesh_fact_v1()) -> map().
to_map(#publish_mesh_fact_v1{topic = T, fact = F, requested_at = R}) ->
    #{topic => T, fact => F, requested_at => R}.

-spec from_map(map()) -> {ok, publish_mesh_fact_v1()} | {error, term()}.
from_map(#{topic := T, fact := F, requested_at := R})
  when is_binary(T), is_map(F), is_integer(R) ->
    {ok, #publish_mesh_fact_v1{topic = T, fact = F, requested_at = R}};
from_map(_) ->
    {error, invalid_publish_mesh_fact_command}.
