%%% @doc seat_denied_v1 — host has rejected a `seat_requested_v1`.
%%%
%%% Reasons: `game_full` (someone else won the race), `lobby_not_accepting`
%%% (lobby past waiting state), `unknown_game` (game_id didn't match
%%% any hosted game — typically not published, just ignored). Other
%%% reasons can be added as the host policy evolves.
%%%
%%% Subscribed by `mpong_lobby_seeker`; matched by `request_id`.
%%%
%%% Topic: io.macula/beam-campus/hecate/mpong/seat_denied_v1
%%% @end
-module(seat_denied_v1).

-behaviour(evoq_event).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([event_type/0]).

-record(seat_denied_v1, {
    request_id :: binary(),
    game_id    :: binary(),
    reason     :: binary(),
    denied_at  :: integer()
}).

-opaque seat_denied_v1() :: #seat_denied_v1{}.
-export_type([seat_denied_v1/0]).

event_type() -> <<"seat_denied_v1">>.

-spec new(map()) -> seat_denied_v1().
new(#{request_id := Rid, game_id := Gid, reason := Reason, denied_at := At}) ->
    new(Rid, Gid, Reason, At).

-spec new(binary(), binary(), binary(), integer()) -> seat_denied_v1().
new(RequestId, GameId, Reason, DeniedAt) ->
    #seat_denied_v1{
        request_id = RequestId,
        game_id = GameId,
        reason = Reason,
        denied_at = DeniedAt
    }.

-spec to_map(seat_denied_v1()) -> map().
to_map(#seat_denied_v1{request_id = Rid, game_id = Gid,
                      reason = Reason, denied_at = At}) ->
    #{
        event_type => event_type(),
        request_id => Rid,
        game_id    => Gid,
        reason     => Reason,
        denied_at  => At
    }.

-spec from_map(map()) -> {ok, seat_denied_v1()} | {error, term()}.
from_map(#{request_id := Rid, game_id := Gid,
           reason := Reason, denied_at := At}) ->
    {ok, new(Rid, Gid, Reason, At)};
from_map(_) ->
    {error, invalid_seat_denied_event}.
