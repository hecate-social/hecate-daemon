%%% @doc player_joined_v1 event
-module(player_joined_v1).

-behaviour(evoq_event).

-export([new/1, new/4, new/5, to_map/1, from_map/1]).
-export([event_type/0]).

-record(player_joined_v1, {
    game_id        :: binary(),
    player_node_id :: binary(),
    wall_index     :: non_neg_integer(),
    joined_at      :: integer(),
    champion_name  :: binary() | undefined,
    transport      :: binary() | undefined,
    country        :: binary() | undefined,
    city           :: binary() | undefined,
    rtt_ms         :: non_neg_integer() | undefined,
    nat_type       :: binary() | undefined
}).

-opaque player_joined_v1() :: #player_joined_v1{}.
-export_type([player_joined_v1/0]).

event_type() -> <<"player_joined_v1">>.

-spec new(map()) -> player_joined_v1().
new(#{game_id := GId, player_node_id := PId, wall_index := WI, joined_at := JAt} = M) ->
    new(GId, PId, WI, JAt, maps:without([game_id, player_node_id, wall_index, joined_at, event_type], M)).

-spec new(binary(), binary(), non_neg_integer(), integer()) -> player_joined_v1().
new(GameId, PlayerNodeId, WallIndex, JoinedAt) ->
    new(GameId, PlayerNodeId, WallIndex, JoinedAt, #{}).

-spec new(binary(), binary(), non_neg_integer(), integer(), map()) -> player_joined_v1().
new(GameId, PlayerNodeId, WallIndex, JoinedAt, Meta) ->
    #player_joined_v1{
        game_id = GameId,
        player_node_id = PlayerNodeId,
        wall_index = WallIndex,
        joined_at = JoinedAt,
        champion_name = maps:get(champion_name, Meta, undefined),
        transport = maps:get(transport, Meta, undefined),
        country = maps:get(country, Meta, undefined),
        city = maps:get(city, Meta, undefined),
        rtt_ms = maps:get(rtt_ms, Meta, undefined),
        nat_type = maps:get(nat_type, Meta, undefined)
    }.

-spec to_map(player_joined_v1()) -> map().
to_map(#player_joined_v1{
    game_id = GId, player_node_id = PId,
    wall_index = WI, joined_at = JAt,
    champion_name = CN, transport = Tr,
    country = Co, city = Ci, rtt_ms = RTT, nat_type = NT
}) ->
    #{
        event_type => <<"player_joined_v1">>,
        game_id => GId,
        player_node_id => PId,
        wall_index => WI,
        joined_at => JAt,
        champion_name => CN,
        transport => Tr,
        country => Co,
        city => Ci,
        rtt_ms => RTT,
        nat_type => NT
    }.

-spec from_map(map()) -> {ok, player_joined_v1()} | {error, term()}.
from_map(#{game_id := GId, player_node_id := PId, wall_index := WI, joined_at := JAt} = M) ->
    {ok, #player_joined_v1{
        game_id = GId, player_node_id = PId, wall_index = WI, joined_at = JAt,
        champion_name = maps:get(champion_name, M, maps:get(<<"champion_name">>, M, undefined)),
        transport = maps:get(transport, M, maps:get(<<"transport">>, M, undefined)),
        country = maps:get(country, M, maps:get(<<"country">>, M, undefined)),
        city = maps:get(city, M, maps:get(<<"city">>, M, undefined)),
        rtt_ms = maps:get(rtt_ms, M, maps:get(<<"rtt_ms">>, M, undefined)),
        nat_type = maps:get(nat_type, M, maps:get(<<"nat_type">>, M, undefined))
    }};
from_map(_) ->
    {error, invalid_player_joined_event}.
