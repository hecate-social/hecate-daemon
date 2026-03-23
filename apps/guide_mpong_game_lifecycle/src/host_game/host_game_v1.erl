%%% @doc host_game_v1 command
-module(host_game_v1).

-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).

-record(host_game_v1, {
    game_id      :: binary(),
    host_node_id :: binary(),
    max_players  :: pos_integer()
}).

-opaque host_game_v1() :: #host_game_v1{}.
-export_type([host_game_v1/0]).

command_type() -> host_game.

-spec new(map()) -> {ok, host_game_v1()} | {error, term()}.
new(#{game_id := GId, host_node_id := HId, max_players := Max}) ->
    {ok, new(GId, HId, Max)};
new(#{game_id := GId, host_node_id := HId}) ->
    {ok, new(GId, HId, 8)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary(), pos_integer()) -> host_game_v1().
new(GameId, HostNodeId, MaxPlayers) ->
    #host_game_v1{
        game_id = GameId,
        host_node_id = HostNodeId,
        max_players = MaxPlayers
    }.

-spec to_map(host_game_v1()) -> map().
to_map(#host_game_v1{
    game_id = GameId,
    host_node_id = HostNodeId,
    max_players = MaxPlayers
}) ->
    #{
        game_id => GameId,
        host_node_id => HostNodeId,
        max_players => MaxPlayers
    }.

-spec from_map(map()) -> {ok, host_game_v1()} | {error, term()}.
from_map(#{game_id := GId, host_node_id := HId, max_players := Max}) ->
    {ok, #host_game_v1{game_id = GId, host_node_id = HId, max_players = Max}};
from_map(#{game_id := GId, host_node_id := HId}) ->
    {ok, #host_game_v1{game_id = GId, host_node_id = HId, max_players = 8}};
from_map(_) ->
    {error, invalid_host_game_command}.
