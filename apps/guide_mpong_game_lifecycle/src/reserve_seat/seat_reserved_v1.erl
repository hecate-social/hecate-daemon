%%% @doc seat_reserved_v1 — host has granted the open seat in a game
%%% to a specific challenger.
%%%
%%% Published by `mpong_lobby_server` after a successful match between
%%% an inbound `seat_requested_v1` and a hosted game with an open seat.
%%% Subscribed by `mpong_lobby_seeker`, which uses `request_id` to
%%% correlate the response back to its own pending request.
%%%
%%% First-wins race: only one challenger gets a `seat_reserved_v1`
%%% per seat. Other simultaneous requesters get `seat_denied_v1`.
%%%
%%% Topic: io.macula/beam-campus/hecate/mpong/seat_reserved_v1
%%% @end
-module(seat_reserved_v1).

-behaviour(evoq_event).

-export([new/1, new/6, to_map/1, from_map/1]).
-export([event_type/0]).

-record(seat_reserved_v1, {
    request_id           :: binary(),
    game_id              :: binary(),
    reserved_for_node_id :: binary(),
    reserved_for_did     :: binary(),
    wall_index           :: non_neg_integer(),
    reserved_at          :: integer()
}).

-opaque seat_reserved_v1() :: #seat_reserved_v1{}.
-export_type([seat_reserved_v1/0]).

event_type() -> <<"seat_reserved_v1">>.

-spec new(map()) -> seat_reserved_v1().
new(#{request_id := Rid, game_id := Gid, reserved_for_node_id := Nid,
      reserved_for_did := Did, wall_index := WI, reserved_at := At}) ->
    new(Rid, Gid, Nid, Did, WI, At).

-spec new(binary(), binary(), binary(), binary(),
          non_neg_integer(), integer()) -> seat_reserved_v1().
new(RequestId, GameId, NodeId, Did, WallIndex, ReservedAt) ->
    #seat_reserved_v1{
        request_id = RequestId,
        game_id = GameId,
        reserved_for_node_id = NodeId,
        reserved_for_did = Did,
        wall_index = WallIndex,
        reserved_at = ReservedAt
    }.

-spec to_map(seat_reserved_v1()) -> map().
to_map(#seat_reserved_v1{
    request_id = Rid, game_id = Gid, reserved_for_node_id = Nid,
    reserved_for_did = Did, wall_index = WI, reserved_at = At}) ->
    #{
        event_type           => event_type(),
        request_id           => Rid,
        game_id              => Gid,
        reserved_for_node_id => Nid,
        reserved_for_did     => Did,
        wall_index           => WI,
        reserved_at          => At
    }.

-spec from_map(map()) -> {ok, seat_reserved_v1()} | {error, term()}.
from_map(#{request_id := Rid, game_id := Gid, reserved_for_node_id := Nid,
           reserved_for_did := Did, wall_index := WI, reserved_at := At}) ->
    {ok, new(Rid, Gid, Nid, Did, WI, At)};
from_map(_) ->
    {error, invalid_seat_reserved_event}.
