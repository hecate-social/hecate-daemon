%%% @doc API handler: GET/POST /api/arcade/gladiators/heroes/:hero_id
%%%
%%% GET:  Get single hero details.
%%% POST: Start a hero duel vs AI.
%%% @end
-module(hero_detail_api).

-export([init/2]).

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0);
        <<"POST">> -> handle_post(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    HeroId = cowboy_req:binding(hero_id, Req0),
    case query_snake_gladiators_store:get_hero(HeroId) of
        {ok, Hero} ->
            %% Strip network_json from response (large payload)
            Compact = maps:remove(network_json, Hero),
            hecate_api_utils:json_ok(200, Compact#{ok => true}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Hero not found">>, Req0)
    end.

%% POST starts a hero duel — same pattern as champion duel but uses hero's network
handle_post(Req0) ->
    HeroId = cowboy_req:binding(hero_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_duel(HeroId, Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_duel(HeroId, Params, Req) ->
    OppAF = to_integer(hecate_api_utils:get_field(opponent_af, Params), 50),
    TickMs = to_integer(hecate_api_utils:get_field(tick_ms, Params), 100),

    case query_snake_gladiators_store:get_hero(HeroId) of
        {ok, #{network_json := NetworkJson}} ->
            NetworkData = json:decode(NetworkJson),
            Network = network_evaluator:from_json(NetworkData),
            MatchId = generate_match_id(),
            Config = #{
                match_id => MatchId,
                network => Network,
                opponent_af => OppAF,
                tick_ms => TickMs,
                hero_id => HeroId
            },
            case gladiator_duel_proc_sup:start_duel(Config) of
                {ok, _Pid} ->
                    hecate_api_utils:json_ok(200, #{
                        ok => true,
                        match_id => MatchId
                    }, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req)
            end;
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Hero not found">>, Req)
    end.

generate_match_id() ->
    Bytes = crypto:strong_rand_bytes(6),
    Hex = binary:encode_hex(Bytes, lowercase),
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    <<"hduel-", Ts/binary, "-", Hex/binary>>.

to_integer(V, _Default) when is_integer(V) -> V;
to_integer(V, _Default) when is_float(V) -> round(V);
to_integer(V, _Default) when is_binary(V) ->
    try binary_to_integer(V) catch _:_ -> 0 end;
to_integer(_, Default) -> Default.
