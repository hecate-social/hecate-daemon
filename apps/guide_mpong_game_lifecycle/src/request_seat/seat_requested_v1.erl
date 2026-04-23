%%% @doc seat_requested_v1 — challenger asks the host of a specific
%%% mpong game to grant them the open seat.
%%%
%%% Published by `mpong_lobby_seeker` after observing a `game_advertised`
%%% fact for a game it wants to join. Subscribed by every mpong host
%%% (`mpong_lobby_server`); a host responds only when the `game_id`
%%% in the request matches one of its own hosted games.
%%%
%%% Race semantics: first matching request wins. Subsequent requests
%%% for the same already-reserved seat receive `seat_denied_v1` with
%%% reason `game_full` (or similar).
%%%
%%% Correlation: every request carries a fresh `request_id` so the
%%% seeker can match the eventual `seat_reserved_v1` /
%%% `seat_denied_v1` response back to its own ask.
%%%
%%% Topic: io.macula/beam-campus/hecate/mpong/seat_requested_v1
%%% @end
-module(seat_requested_v1).

-behaviour(evoq_event).

-export([new/1, new/6, to_map/1, from_map/1]).
-export([event_type/0]).

-record(seat_requested_v1, {
    request_id         :: binary(),
    game_id            :: binary(),
    challenger_node_id :: binary(),
    challenger_did     :: binary(),
    champion           :: map(),
    requested_at       :: integer()
}).

-opaque seat_requested_v1() :: #seat_requested_v1{}.
-export_type([seat_requested_v1/0]).

event_type() -> <<"seat_requested_v1">>.

-spec new(map()) -> seat_requested_v1().
new(#{request_id := Rid, game_id := Gid, challenger_node_id := Nid,
      challenger_did := Did, champion := Champ, requested_at := At}) ->
    new(Rid, Gid, Nid, Did, Champ, At).

-spec new(binary(), binary(), binary(), binary(), map(), integer())
        -> seat_requested_v1().
new(RequestId, GameId, NodeId, Did, Champion, RequestedAt) ->
    #seat_requested_v1{
        request_id = RequestId,
        game_id = GameId,
        challenger_node_id = NodeId,
        challenger_did = Did,
        champion = Champion,
        requested_at = RequestedAt
    }.

-spec to_map(seat_requested_v1()) -> map().
to_map(#seat_requested_v1{
    request_id = Rid, game_id = Gid, challenger_node_id = Nid,
    challenger_did = Did, champion = Champ, requested_at = At}) ->
    #{
        event_type         => event_type(),
        request_id         => Rid,
        game_id            => Gid,
        challenger_node_id => Nid,
        challenger_did     => Did,
        champion           => Champ,
        requested_at       => At
    }.

-spec from_map(map()) -> {ok, seat_requested_v1()} | {error, term()}.
from_map(#{request_id := Rid, game_id := Gid, challenger_node_id := Nid,
           challenger_did := Did, champion := Champ, requested_at := At}) ->
    {ok, new(Rid, Gid, Nid, Did, Champ, At)};
from_map(_) ->
    {error, invalid_seat_requested_event}.
