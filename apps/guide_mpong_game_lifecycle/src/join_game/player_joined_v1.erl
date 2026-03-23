%%% @doc player_joined_v1 event
-module(player_joined_v1).

-behaviour(evoq_event).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([event_type/0]).

-record(player_joined_v1, {
    game_id        :: binary(),
    player_node_id :: binary(),
    wall_index     :: non_neg_integer(),
    joined_at      :: integer()
}).

-opaque player_joined_v1() :: #player_joined_v1{}.
-export_type([player_joined_v1/0]).

event_type() -> <<"player_joined_v1">>.

-spec new(map()) -> player_joined_v1().
new(#{game_id := GId, player_node_id := PId, wall_index := WI, joined_at := JAt}) ->
    new(GId, PId, WI, JAt).

-spec new(binary(), binary(), non_neg_integer(), integer()) -> player_joined_v1().
new(GameId, PlayerNodeId, WallIndex, JoinedAt) ->
    #player_joined_v1{
        game_id = GameId,
        player_node_id = PlayerNodeId,
        wall_index = WallIndex,
        joined_at = JoinedAt
    }.

-spec to_map(player_joined_v1()) -> map().
to_map(#player_joined_v1{
    game_id = GId, player_node_id = PId,
    wall_index = WI, joined_at = JAt
}) ->
    #{
        event_type => <<"player_joined_v1">>,
        game_id => GId,
        player_node_id => PId,
        wall_index => WI,
        joined_at => JAt
    }.

-spec from_map(map()) -> {ok, player_joined_v1()} | {error, term()}.
from_map(#{game_id := GId, player_node_id := PId, wall_index := WI, joined_at := JAt}) ->
    {ok, #player_joined_v1{game_id = GId, player_node_id = PId, wall_index = WI, joined_at = JAt}};
from_map(_) ->
    {error, invalid_player_joined_event}.
