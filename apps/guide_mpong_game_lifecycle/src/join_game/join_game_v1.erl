%%% @doc join_game_v1 command
-module(join_game_v1).

-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(join_game_v1, {
    game_id        :: binary(),
    player_node_id :: binary()
}).

-opaque join_game_v1() :: #join_game_v1{}.
-export_type([join_game_v1/0]).

command_type() -> join_game.

-spec new(map()) -> {ok, join_game_v1()} | {error, term()}.
new(#{game_id := GId, player_node_id := PId}) ->
    {ok, new(GId, PId)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary()) -> join_game_v1().
new(GameId, PlayerNodeId) ->
    #join_game_v1{game_id = GameId, player_node_id = PlayerNodeId}.

-spec to_map(join_game_v1()) -> map().
to_map(#join_game_v1{game_id = GId, player_node_id = PId}) ->
    #{game_id => GId, player_node_id => PId}.

-spec from_map(map()) -> {ok, join_game_v1()} | {error, term()}.
from_map(#{game_id := GId, player_node_id := PId}) ->
    {ok, #join_game_v1{game_id = GId, player_node_id = PId}};
from_map(_) ->
    {error, invalid_join_game_command}.
