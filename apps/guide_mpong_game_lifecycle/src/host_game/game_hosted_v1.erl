%%% @doc game_hosted_v1 event
-module(game_hosted_v1).

-behaviour(evoq_event).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([event_type/0]).

-record(game_hosted_v1, {
    game_id      :: binary(),
    host_node_id :: binary(),
    max_players  :: pos_integer(),
    hosted_at    :: integer()
}).

-opaque game_hosted_v1() :: #game_hosted_v1{}.
-export_type([game_hosted_v1/0]).

event_type() -> <<"game_hosted_v1">>.

-spec new(map()) -> game_hosted_v1().
new(#{game_id := GId, host_node_id := HId, max_players := Max, hosted_at := At}) ->
    new(GId, HId, Max, At).

-spec new(binary(), binary(), pos_integer(), integer()) -> game_hosted_v1().
new(GameId, HostNodeId, MaxPlayers, HostedAt) ->
    #game_hosted_v1{
        game_id = GameId,
        host_node_id = HostNodeId,
        max_players = MaxPlayers,
        hosted_at = HostedAt
    }.

-spec to_map(game_hosted_v1()) -> map().
to_map(#game_hosted_v1{
    game_id = GameId,
    host_node_id = HostNodeId,
    max_players = MaxPlayers,
    hosted_at = HostedAt
}) ->
    #{
        event_type => <<"game_hosted_v1">>,
        game_id => GameId,
        host_node_id => HostNodeId,
        max_players => MaxPlayers,
        hosted_at => HostedAt
    }.

-spec from_map(map()) -> {ok, game_hosted_v1()} | {error, term()}.
from_map(#{game_id := GId, host_node_id := HId, max_players := Max, hosted_at := At}) ->
    {ok, #game_hosted_v1{game_id = GId, host_node_id = HId, max_players = Max, hosted_at = At}};
from_map(_) ->
    {error, invalid_game_hosted_event}.
