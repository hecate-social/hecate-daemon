%%% @doc game_ended_v1 event
-module(game_ended_v1).

-behaviour(evoq_event).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([event_type/0]).

-record(game_ended_v1, {
    game_id        :: binary(),
    winner_node_id :: binary() | undefined,
    reason         :: binary(),
    ended_at       :: integer()
}).

-opaque game_ended_v1() :: #game_ended_v1{}.
-export_type([game_ended_v1/0]).

event_type() -> <<"game_ended_v1">>.

-spec new(map()) -> game_ended_v1().
new(#{game_id := GId, winner_node_id := W, reason := R, ended_at := At}) ->
    new(GId, W, R, At).

-spec new(binary(), binary() | undefined, binary(), integer()) -> game_ended_v1().
new(GameId, WinnerNodeId, Reason, EndedAt) ->
    #game_ended_v1{
        game_id = GameId,
        winner_node_id = WinnerNodeId,
        reason = Reason,
        ended_at = EndedAt
    }.

-spec to_map(game_ended_v1()) -> map().
to_map(#game_ended_v1{
    game_id = GameId,
    winner_node_id = WinnerNodeId,
    reason = Reason,
    ended_at = EndedAt
}) ->
    #{
        event_type => <<"game_ended_v1">>,
        game_id => GameId,
        winner_node_id => WinnerNodeId,
        reason => Reason,
        ended_at => EndedAt
    }.

-spec from_map(map()) -> {ok, game_ended_v1()} | {error, term()}.
from_map(#{game_id := GId, reason := R, ended_at := At} = Map) ->
    Winner = maps:get(winner_node_id, Map, undefined),
    {ok, #game_ended_v1{game_id = GId, winner_node_id = Winner, reason = R, ended_at = At}};
from_map(_) ->
    {error, invalid_game_ended_event}.
