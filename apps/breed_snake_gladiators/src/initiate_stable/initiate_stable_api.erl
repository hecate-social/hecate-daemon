%%% @doc API handler: POST/GET /api/arcade/gladiators/stables
%%%
%%% POST: Start a new training stable.
%%% GET:  List all stables (dispatches to query store).
%%% @end
-module(initiate_stable_api).

-include("gladiator.hrl").

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables", ?MODULE, []}].

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
    ChampionCount = clamp(to_integer(hecate_api_utils:get_field(champion_count, Params),
                                     ?DEFAULT_CHAMPION_COUNT),
                          1, ?MAX_CHAMPION_COUNT),

    %% Optional per-stable training config overrides
    TrainingConfig = extract_training_config(Params),

    %% Extract enable_ltc and enable_lc_chain from training_config
    EnableLtc = extract_enable_ltc(TrainingConfig),
    EnableLcChain = extract_enable_lc_chain(TrainingConfig),

    %% Check tuning budget if fitness weights are present
    case check_budget(TrainingConfig) of
        {error, budget_exceeded} ->
            hecate_api_utils:json_error(400, <<"Fitness tuning budget exceeded">>, Req);
        ok ->
            StableId = generate_stable_id(),

            %% Load seed networks from all champions if seed_stable_id is provided
            SeedNetworks = load_seed_networks(SeedStableId),

            Config = #{
                stable_id => StableId,
                population_size => PopSize,
                max_generations => MaxGen,
                opponent_af => OppAF,
                episodes_per_eval => Episodes,
                seed_networks => SeedNetworks,
                training_config => TrainingConfig,
                champion_count => ChampionCount,
                enable_ltc => EnableLtc,
                enable_lc_chain => EnableLcChain
            },

            case training_proc_sup:start_training(Config) of
                {ok, _Pid} ->
                    Response = #{
                        stable_id => StableId,
                        population_size => PopSize,
                        max_generations => MaxGen,
                        opponent_af => OppAF,
                        episodes_per_eval => Episodes,
                        champion_count => ChampionCount,
                        enable_ltc => EnableLtc,
                        enable_lc_chain => EnableLcChain,
                        status => <<"training">>
                    },
                    Response1 = case SeedStableId of
                        undefined -> Response;
                        null -> Response;
                        _ -> Response#{seed_stable_id => SeedStableId}
                    end,
                    Response2 = case map_size(TrainingConfig) of
                        0 -> Response1;
                        _ -> Response1#{training_config => TrainingConfig}
                    end,
                    hecate_api_utils:json_ok(201, Response2, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req)
            end
    end.

check_budget(TrainingConfig) ->
    case maps:get(fitness_weights, TrainingConfig, undefined) of
        undefined -> ok;
        Weights ->
            case gladiator_fitness_config:within_budget(Weights, ?DEFAULT_TUNING_BUDGET) of
                true -> ok;
                false -> {error, budget_exceeded}
            end
    end.

%% Extract optional training config overrides from the request body.
%% Supported keys:
%%   max_ticks: max game ticks per episode (default 500)
%%   gladiator_af: gladiator's asshole factor (default 0)
%%   fitness_weights: map of weight overrides
%%   fitness_preset: named preset (balanced, aggressive, forager, survivor, assassin)
extract_training_config(Params) ->
    ConfigMap = hecate_api_utils:get_field(training_config, Params),
    case ConfigMap of
        undefined -> #{};
        null -> #{};
        M when is_map(M) ->
            Fields = [{max_ticks, 500}, {gladiator_af, 0}],
            Base = maps:from_list([
                {K, to_integer(hecate_api_utils:get_field(K, M), Default)}
                || {K, Default} <- Fields,
                   hecate_api_utils:get_field(K, M) =/= undefined
            ]),
            %% Handle enable_ltc
            Base1 = case hecate_api_utils:get_field(enable_ltc, M) of
                undefined -> Base;
                null -> Base;
                V -> Base#{enable_ltc => V =:= true orelse V =:= <<"true">>}
            end,
            %% Handle enable_lc_chain
            Base2 = case hecate_api_utils:get_field(enable_lc_chain, M) of
                undefined -> Base1;
                null -> Base1;
                V2 -> Base1#{enable_lc_chain => V2 =:= true orelse V2 =:= <<"true">>}
            end,
            %% Handle fitness weights: preset or custom
            WithWeights = extract_fitness_weights(M, Base2),
            WithWeights;
        _ -> #{}
    end.

extract_fitness_weights(ConfigMap, Base) ->
    Preset = hecate_api_utils:get_field(fitness_preset, ConfigMap),
    UserWeights = hecate_api_utils:get_field(fitness_weights, ConfigMap),
    Presets = gladiator_fitness_config:presets(),
    RawWeights = case {Preset, UserWeights} of
        {undefined, undefined} -> undefined;
        {undefined, null} -> undefined;
        {null, undefined} -> undefined;
        {null, null} -> undefined;
        {_, W} when is_map(W) -> atomize_weight_keys(W);
        {P, _} when is_binary(P) ->
            case maps:get(binary_to_existing_atom(P), Presets, undefined) of
                undefined -> undefined;
                PresetWeights -> PresetWeights
            end;
        _ -> undefined
    end,
    case RawWeights of
        undefined -> Base;
        _ ->
            case gladiator_fitness_config:validate_weights(RawWeights) of
                {ok, Validated} ->
                    Base#{fitness_weights => Validated};
                {error, _} ->
                    Base
            end
    end.

%% Convert binary keys to atoms for weight map (only known keys).
atomize_weight_keys(Map) when is_map(Map) ->
    Known = [survival_weight, food_weight, win_bonus, draw_bonus,
             kill_bonus, proximity_weight, circle_penalty, wall_kill_bonus],
    maps:from_list([
        {K, to_float(maps:get(atom_to_binary(K), Map, undefined))}
        || K <- Known,
           maps:is_key(atom_to_binary(K), Map)
    ]).

to_float(V) when is_float(V) -> V;
to_float(V) when is_integer(V) -> V + 0.0;
to_float(_) -> 0.0.

load_seed_networks(undefined) -> [];
load_seed_networks(null) -> [];
load_seed_networks(SeedStableId) when is_binary(SeedStableId) ->
    case query_snake_gladiators_store:get_champions(SeedStableId) of
        {ok, []} ->
            logger:warning("[gladiators] Seed stable ~s has no champions, using random", [SeedStableId]),
            [];
        {ok, Champions} ->
            lists:filtermap(fun(#{network_json := NetworkJson}) ->
                NetworkData = json:decode(NetworkJson),
                case network_evaluator:from_json(NetworkData) of
                    {ok, Network} ->
                        Topology = network_evaluator:get_topology(Network),
                        [InputSize | _] = maps:get(layer_sizes, Topology),
                        case InputSize =:= ?GLADIATOR_INPUTS of
                            true -> {true, Network};
                            false ->
                                logger:warning("[gladiators] Seed champion from ~s has ~p inputs "
                                               "(expected ~p), skipping",
                                               [SeedStableId, InputSize, ?GLADIATOR_INPUTS]),
                                false
                        end;
                    {error, Reason} ->
                        logger:warning("[gladiators] Seed champion from ~s has invalid network: ~p, skipping",
                                       [SeedStableId, Reason]),
                        false
                end
            end, Champions)
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

clamp(V, Min, _Max) when V < Min -> Min;
clamp(V, _Min, Max) when V > Max -> Max;
clamp(V, _Min, _Max) -> V.

extract_enable_ltc(TrainingConfig) when is_map(TrainingConfig) ->
    case maps:get(enable_ltc, TrainingConfig, undefined) of
        true -> true;
        <<"true">> -> true;
        _ -> false
    end;
extract_enable_ltc(_) -> false.

extract_enable_lc_chain(TrainingConfig) when is_map(TrainingConfig) ->
    case maps:get(enable_lc_chain, TrainingConfig, undefined) of
        true -> true;
        <<"true">> -> true;
        _ -> false
    end;
extract_enable_lc_chain(_) -> false.
