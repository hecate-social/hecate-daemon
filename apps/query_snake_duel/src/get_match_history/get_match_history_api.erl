%%% @doc API handler: GET /api/arcade/snake-duel/history
%%% Returns recent match history, most recent first.
-module(get_match_history_api).

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/snake-duel/history", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Qs = cowboy_req:parse_qs(Req0),
    Limit = parse_int(proplists:get_value(<<"limit">>, Qs, <<"20">>), 20),
    Sql = "SELECT match_id, winner, af1, af2, tick_ms, score1, score2,
                  ticks, started_at, ended_at
           FROM matches ORDER BY ended_at DESC LIMIT ?1",
    case query_snake_duel_store:query(Sql, [Limit]) of
        {ok, Rows} ->
            Matches = [row_to_map(R) || R <- Rows],
            hecate_api_utils:json_ok(#{matches => Matches}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

row_to_map([MId, Winner, AF1, AF2, TickMs, Sc1, Sc2, Ticks, StartedAt, EndedAt]) ->
    #{match_id => MId, winner => Winner,
      af1 => AF1, af2 => AF2, tick_ms => TickMs,
      score1 => Sc1, score2 => Sc2,
      ticks => Ticks,
      started_at => StartedAt, ended_at => EndedAt}.

parse_int(Bin, Default) when is_binary(Bin) ->
    try binary_to_integer(Bin) catch _:_ -> Default end;
parse_int(_, Default) -> Default.
