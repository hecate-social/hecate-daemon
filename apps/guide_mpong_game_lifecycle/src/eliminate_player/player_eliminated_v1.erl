%%% @doc player_eliminated_v1 event
-module(player_eliminated_v1).

-behaviour(evoq_event).

-export([new/1, new/5, to_map/1, from_map/1]).
-export([event_type/0]).

-record(player_eliminated_v1, {
    game_id         :: binary(),
    player_node_id  :: binary(),
    reason          :: binary(),
    eliminated_at   :: integer(),
    remaining_count :: non_neg_integer()
}).

-opaque player_eliminated_v1() :: #player_eliminated_v1{}.
-export_type([player_eliminated_v1/0]).

event_type() -> <<"player_eliminated_v1">>.

-spec new(map()) -> player_eliminated_v1().
new(#{game_id := GId, player_node_id := PId, reason := R,
      eliminated_at := EAt, remaining_count := RC}) ->
    new(GId, PId, R, EAt, RC).

-spec new(binary(), binary(), binary(), integer(), non_neg_integer()) -> player_eliminated_v1().
new(GameId, PlayerNodeId, Reason, EliminatedAt, RemainingCount) ->
    #player_eliminated_v1{
        game_id = GameId,
        player_node_id = PlayerNodeId,
        reason = Reason,
        eliminated_at = EliminatedAt,
        remaining_count = RemainingCount
    }.

-spec to_map(player_eliminated_v1()) -> map().
to_map(#player_eliminated_v1{
    game_id = GId, player_node_id = PId,
    reason = R, eliminated_at = EAt, remaining_count = RC
}) ->
    #{
        event_type => <<"player_eliminated_v1">>,
        game_id => GId,
        player_node_id => PId,
        reason => R,
        eliminated_at => EAt,
        remaining_count => RC
    }.

-spec from_map(map()) -> {ok, player_eliminated_v1()} | {error, term()}.
from_map(#{game_id := GId, player_node_id := PId, reason := R,
           eliminated_at := EAt, remaining_count := RC}) ->
    {ok, #player_eliminated_v1{game_id = GId, player_node_id = PId,
                                reason = R, eliminated_at = EAt,
                                remaining_count = RC}};
from_map(_) ->
    {error, invalid_player_eliminated_event}.
