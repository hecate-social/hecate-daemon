%%% @doc end_game_v1 command
-module(end_game_v1).

-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).

-record(end_game_v1, {
    game_id        :: binary(),
    winner_node_id :: binary() | undefined,
    reason         :: binary()
}).

-opaque end_game_v1() :: #end_game_v1{}.
-export_type([end_game_v1/0]).

command_type() -> end_game.

-spec new(map()) -> {ok, end_game_v1()} | {error, term()}.
new(#{game_id := GId, reason := Reason} = Map) ->
    Winner = maps:get(winner_node_id, Map, undefined),
    {ok, new(GId, Winner, Reason)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary() | undefined, binary()) -> end_game_v1().
new(GameId, WinnerNodeId, Reason) ->
    #end_game_v1{
        game_id = GameId,
        winner_node_id = WinnerNodeId,
        reason = Reason
    }.

-spec to_map(end_game_v1()) -> map().
to_map(#end_game_v1{
    game_id = GameId,
    winner_node_id = WinnerNodeId,
    reason = Reason
}) ->
    #{
        game_id => GameId,
        winner_node_id => WinnerNodeId,
        reason => Reason
    }.

-spec from_map(map()) -> {ok, end_game_v1()} | {error, term()}.
from_map(#{game_id := GId, reason := R} = Map) ->
    Winner = maps:get(winner_node_id, Map, undefined),
    {ok, #end_game_v1{game_id = GId, winner_node_id = Winner, reason = R}};
from_map(_) ->
    {error, invalid_end_game_command}.
