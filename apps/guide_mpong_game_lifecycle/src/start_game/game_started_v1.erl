%%% @doc game_started_v1 event
-module(game_started_v1).

-behaviour(evoq_event).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([event_type/0]).

-record(game_started_v1, {
    game_id      :: binary(),
    player_count :: pos_integer(),
    started_at   :: integer()
}).

-opaque game_started_v1() :: #game_started_v1{}.
-export_type([game_started_v1/0]).

event_type() -> <<"game_started_v1">>.

-spec new(map()) -> game_started_v1().
new(#{game_id := GId, player_count := PC, started_at := SAt}) ->
    new(GId, PC, SAt).

-spec new(binary(), pos_integer(), integer()) -> game_started_v1().
new(GameId, PlayerCount, StartedAt) ->
    #game_started_v1{game_id = GameId, player_count = PlayerCount, started_at = StartedAt}.

-spec to_map(game_started_v1()) -> map().
to_map(#game_started_v1{game_id = GId, player_count = PC, started_at = SAt}) ->
    #{event_type => <<"game_started_v1">>, game_id => GId, player_count => PC, started_at => SAt}.

-spec from_map(map()) -> {ok, game_started_v1()} | {error, term()}.
from_map(#{game_id := GId, player_count := PC, started_at := SAt}) ->
    {ok, #game_started_v1{game_id = GId, player_count = PC, started_at = SAt}};
from_map(_) ->
    {error, invalid_game_started_event}.
