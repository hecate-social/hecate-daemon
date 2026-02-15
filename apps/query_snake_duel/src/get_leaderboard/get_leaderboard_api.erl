%%% @doc API handler: GET /api/arcade/snake-duel/leaderboard
%%% Returns aggregate win/loss stats. Since Snake Duel is AI-vs-AI,
%%% the leaderboard tracks AF configurations by win rate.
-module(get_leaderboard_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Sql = "SELECT winner, COUNT(*) as wins,
                  AVG(CASE WHEN winner = 'player1' THEN score1
                           WHEN winner = 'player2' THEN score2
                           ELSE 0 END) as avg_score
           FROM matches
           WHERE winner != 'draw'
           GROUP BY winner
           ORDER BY wins DESC",
    case query_snake_duel_store:query(Sql, []) of
        {ok, Rows} ->
            Stats = [#{winner => W, wins => Wins, avg_score => AvgScore}
                     || [W, Wins, AvgScore] <- Rows],
            %% Also get total matches
            {ok, [[Total]]} = query_snake_duel_store:query(
                "SELECT COUNT(*) FROM matches", []),
            {ok, [[Draws]]} = query_snake_duel_store:query(
                "SELECT COUNT(*) FROM matches WHERE winner = 'draw'", []),
            hecate_api_utils:json_ok(#{
                total_matches => Total,
                draws => Draws,
                stats => Stats
            }, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
