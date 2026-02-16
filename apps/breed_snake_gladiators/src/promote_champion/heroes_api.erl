%%% @doc API handler: POST/GET /api/arcade/gladiators/heroes
%%%
%%% POST: Promote a champion to a permanent hero.
%%% GET:  List all heroes.
%%% @end
-module(heroes_api).

-export([init/2]).

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0);
        <<"GET">> -> handle_get(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    {ok, Heroes} = query_snake_gladiators_store:get_heroes(),
    %% Strip network_json from list response (large payload)
    Compact = [maps:remove(network_json, H) || H <- Heroes],
    hecate_api_utils:json_ok(200, #{ok => true, heroes => Compact}, Req0).

handle_post(Req0) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_promote(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_promote(Params, Req) ->
    StableId = hecate_api_utils:get_field(stable_id, Params),
    Name = hecate_api_utils:get_field(name, Params),

    case {StableId, Name} of
        {undefined, _} ->
            hecate_api_utils:bad_request(<<"Missing stable_id">>, Req);
        {_, undefined} ->
            hecate_api_utils:bad_request(<<"Missing name">>, Req);
        {_, _} ->
            case query_snake_gladiators_store:get_champion(StableId) of
                {ok, Champion} ->
                    HeroId = generate_hero_id(),
                    PromotedAt = erlang:system_time(millisecond),
                    HeroData = #{
                        hero_id => HeroId,
                        name => Name,
                        stable_id => StableId,
                        network_json => maps:get(network_json, Champion),
                        fitness => maps:get(fitness, Champion),
                        generation => maps:get(generation, Champion),
                        promoted_at => PromotedAt
                    },
                    query_snake_gladiators_store:promote_champion(HeroData),
                    hecate_api_utils:json_ok(201, #{
                        ok => true,
                        hero_id => HeroId,
                        name => Name,
                        fitness => maps:get(fitness, Champion),
                        generation => maps:get(generation, Champion),
                        origin_stable_id => StableId,
                        promoted_at => PromotedAt
                    }, Req);
                {error, not_found} ->
                    hecate_api_utils:json_error(404, <<"Champion not found">>, Req)
            end
    end.

generate_hero_id() ->
    Bytes = crypto:strong_rand_bytes(8),
    Hex = binary:encode_hex(Bytes, lowercase),
    <<"hero-", Hex/binary>>.
