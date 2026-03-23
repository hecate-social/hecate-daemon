%%% @doc player_left_v1 event
-module(player_left_v1).

-behaviour(evoq_event).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([event_type/0]).

-record(player_left_v1, {
    game_id        :: binary(),
    player_node_id :: binary(),
    left_at        :: integer()
}).

-opaque player_left_v1() :: #player_left_v1{}.
-export_type([player_left_v1/0]).

event_type() -> <<"player_left_v1">>.

-spec new(map()) -> player_left_v1().
new(#{game_id := GId, player_node_id := PId, left_at := LAt}) ->
    new(GId, PId, LAt).

-spec new(binary(), binary(), integer()) -> player_left_v1().
new(GameId, PlayerNodeId, LeftAt) ->
    #player_left_v1{game_id = GameId, player_node_id = PlayerNodeId, left_at = LeftAt}.

-spec to_map(player_left_v1()) -> map().
to_map(#player_left_v1{game_id = GId, player_node_id = PId, left_at = LAt}) ->
    #{event_type => <<"player_left_v1">>, game_id => GId, player_node_id => PId, left_at => LAt}.

-spec from_map(map()) -> {ok, player_left_v1()} | {error, term()}.
from_map(#{game_id := GId, player_node_id := PId, left_at := LAt}) ->
    {ok, #player_left_v1{game_id = GId, player_node_id = PId, left_at = LAt}};
from_map(_) ->
    {error, invalid_player_left_event}.
