%%% @doc API handler: POST/GET /api/arcade/gladiators/stables
%%%
%%% POST: Start a new training stable.
%%% GET:  List all stables (dispatches to query store).
%%% @end
-module(initiate_stable_api).

-export([init/2]).

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0);
        <<"GET">> -> handle_get(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_initiate(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

handle_get(Req0) ->
    {ok, Stables} = query_snake_gladiators_store:get_stables(),
    hecate_api_utils:json_ok(200, #{stables => Stables}, Req0).

do_initiate(Params, Req) ->
    PopSize = to_integer(hecate_api_utils:get_field(population_size, Params), 50),
    MaxGen = to_integer(hecate_api_utils:get_field(max_generations, Params), 100),
    OppAF = to_integer(hecate_api_utils:get_field(opponent_af, Params), 50),
    Episodes = to_integer(hecate_api_utils:get_field(episodes_per_eval, Params), 3),
    SeedStableId = hecate_api_utils:get_field(seed_stable_id, Params),

    StableId = generate_stable_id(),

    %% Load seed networks from champion if seed_stable_id is provided
    SeedNetworks = load_seed_networks(SeedStableId),

    Config = #{
        stable_id => StableId,
        population_size => PopSize,
        max_generations => MaxGen,
        opponent_af => OppAF,
        episodes_per_eval => Episodes,
        seed_networks => SeedNetworks
    },

    case training_proc_sup:start_training(Config) of
        {ok, _Pid} ->
            Response = #{
                stable_id => StableId,
                population_size => PopSize,
                max_generations => MaxGen,
                opponent_af => OppAF,
                episodes_per_eval => Episodes,
                status => <<"training">>
            },
            Response1 = case SeedStableId of
                undefined -> Response;
                null -> Response;
                _ -> Response#{seed_stable_id => SeedStableId}
            end,
            hecate_api_utils:json_ok(201, Response1, Req);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req)
    end.

load_seed_networks(undefined) -> [];
load_seed_networks(null) -> [];
load_seed_networks(SeedStableId) when is_binary(SeedStableId) ->
    case query_snake_gladiators_store:get_champion(SeedStableId) of
        {ok, #{network_json := NetworkJson}} ->
            NetworkData = json:decode(NetworkJson),
            Network = network_evaluator:from_json(NetworkData),
            [Network];
        {error, _} ->
            logger:warning("[gladiators] Seed stable ~s has no champion, using random", [SeedStableId]),
            []
    end;
load_seed_networks(_) -> [].

generate_stable_id() ->
    Bytes = crypto:strong_rand_bytes(8),
    Hex = binary:encode_hex(Bytes, lowercase),
    <<"stable-", Hex/binary>>.

to_integer(V, _Default) when is_integer(V) -> V;
to_integer(V, _Default) when is_float(V) -> round(V);
to_integer(V, _Default) when is_binary(V) ->
    try binary_to_integer(V) catch _:_ -> 0 end;
to_integer(_, Default) -> Default.
