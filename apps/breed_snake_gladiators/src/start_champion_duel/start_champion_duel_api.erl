%%% @doc API handler: POST /api/arcade/gladiators/stables/:stable_id/duel
%%%
%%% Starts a champion duel match — the trained champion plays against
%%% a heuristic AI opponent. Returns match_id for SSE streaming.
%%% @end
-module(start_champion_duel_api).

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id/duel", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0) ->
    StableId = cowboy_req:binding(stable_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            OppAF = to_integer(hecate_api_utils:get_field(opponent_af, Params), 50),
            TickMs = to_integer(hecate_api_utils:get_field(tick_ms, Params), 100),

            Cmd = start_champion_duel_v1:new(#{
                stable_id => StableId,
                opponent_af => OppAF,
                tick_ms => TickMs
            }),

            case maybe_start_champion_duel:handle(Cmd) of
                {ok, MatchId} ->
                    hecate_api_utils:json_ok(200, #{
                        ok => true,
                        match_id => MatchId
                    }, Req1);
                {error, {champion_not_found, _}} ->
                    hecate_api_utils:json_error(404, <<"Champion not found">>, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

to_integer(V, _Default) when is_integer(V) -> V;
to_integer(V, _Default) when is_float(V) -> round(V);
to_integer(V, _Default) when is_binary(V) ->
    try binary_to_integer(V) catch _:_ -> 0 end;
to_integer(_, Default) -> Default.
