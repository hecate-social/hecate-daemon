%%% @doc eliminate_player_v1 command
-module(eliminate_player_v1).

-behaviour(evoq_command).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([command_type/0]).

-record(eliminate_player_v1, {
    game_id        :: binary(),
    player_node_id :: binary(),
    reason         :: binary(),
    eliminated_at  :: integer()
}).

-opaque eliminate_player_v1() :: #eliminate_player_v1{}.
-export_type([eliminate_player_v1/0]).

command_type() -> eliminate_player.

-spec new(map()) -> {ok, eliminate_player_v1()} | {error, term()}.
new(#{game_id := GId, player_node_id := PId, reason := R, eliminated_at := EAt}) ->
    {ok, new(GId, PId, R, EAt)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary(), binary(), integer()) -> eliminate_player_v1().
new(GameId, PlayerNodeId, Reason, EliminatedAt) ->
    #eliminate_player_v1{
        game_id = GameId,
        player_node_id = PlayerNodeId,
        reason = Reason,
        eliminated_at = EliminatedAt
    }.

-spec to_map(eliminate_player_v1()) -> map().
to_map(#eliminate_player_v1{
    game_id = GId, player_node_id = PId,
    reason = R, eliminated_at = EAt
}) ->
    #{game_id => GId, player_node_id => PId, reason => R, eliminated_at => EAt}.

-spec from_map(map()) -> {ok, eliminate_player_v1()} | {error, term()}.
from_map(#{game_id := GId, player_node_id := PId, reason := R, eliminated_at := EAt}) ->
    {ok, #eliminate_player_v1{game_id = GId, player_node_id = PId, reason = R, eliminated_at = EAt}};
from_map(_) ->
    {error, invalid_eliminate_player_command}.
