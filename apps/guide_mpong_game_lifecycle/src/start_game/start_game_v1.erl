%%% @doc start_game_v1 command
-module(start_game_v1).

-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(start_game_v1, {
    game_id      :: binary(),
    host_node_id :: binary()
}).

-opaque start_game_v1() :: #start_game_v1{}.
-export_type([start_game_v1/0]).

command_type() -> start_game.

-spec new(map()) -> {ok, start_game_v1()} | {error, term()}.
new(#{game_id := GId, host_node_id := HId}) ->
    {ok, new(GId, HId)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary()) -> start_game_v1().
new(GameId, HostNodeId) ->
    #start_game_v1{game_id = GameId, host_node_id = HostNodeId}.

-spec to_map(start_game_v1()) -> map().
to_map(#start_game_v1{game_id = GId, host_node_id = HId}) ->
    #{game_id => GId, host_node_id => HId}.

-spec from_map(map()) -> {ok, start_game_v1()} | {error, term()}.
from_map(#{game_id := GId, host_node_id := HId}) ->
    {ok, #start_game_v1{game_id = GId, host_node_id = HId}};
from_map(_) ->
    {error, invalid_start_game_command}.
