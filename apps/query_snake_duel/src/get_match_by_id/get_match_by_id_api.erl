%%% @doc API handler: GET /api/arcade/snake-duel/matches/:match_id/result
%%% Returns a completed match result.
-module(get_match_by_id_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    MatchId = cowboy_req:binding(match_id, Req0),
    Sql = "SELECT match_id, winner, af1, af2, tick_ms, score1, score2,
                  ticks, started_at, ended_at
           FROM matches WHERE match_id = ?1",
    case query_snake_duel_store:query(Sql, [MatchId]) of
        {ok, [[MId, Winner, AF1, AF2, TickMs, Sc1, Sc2, Ticks, StartedAt, EndedAt]]} ->
            hecate_api_utils:json_ok(#{
                match_id => MId, winner => Winner,
                af1 => AF1, af2 => AF2, tick_ms => TickMs,
                score1 => Sc1, score2 => Sc2,
                ticks => Ticks,
                started_at => StartedAt, ended_at => EndedAt
            }, Req0);
        {ok, []} ->
            hecate_api_utils:not_found(Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
