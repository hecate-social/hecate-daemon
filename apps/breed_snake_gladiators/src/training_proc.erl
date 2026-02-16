%%% @doc Gen_server managing one gladiator training session.
%%%
%%% Owns the neuroevolution_server, receives generation events via
%%% event_handler callback, broadcasts progress via pg group.
%%% SSE stream handlers join the training's pg group
%%% to receive live progress updates.
%%%
%%% Training lifecycle:
%%%   1. start_link(Config) -- builds bridge, starts neuroevolution_server
%%%   2. Receives generation_complete events, broadcasts progress
%%%   3. Records generation stats to query_snake_gladiators_store
%%%   4. On training_complete: extracts champion, records, stops
%%% @end
-module(training_proc).
-behaviour(gen_server).

-include_lib("faber_neuroevolution/include/neuroevolution.hrl").
-include("gladiator.hrl").

-export([start_link/1, get_status/1, halt/1]).
-export([handle_event/2]).
-export([init/1, handle_info/2, handle_call/3, handle_cast/2, terminate/2]).

-record(training, {
    stable_id      :: binary(),
    neuro_pid      :: pid(),
    max_generations :: non_neg_integer(),
    last_generation :: non_neg_integer(),
    best_fitness   :: float(),
    avg_fitness    :: float(),
    worst_fitness  :: float(),
    started_at     :: non_neg_integer()
}).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------

-spec start_link(map()) -> {ok, pid()} | {error, term()}.
start_link(Config) ->
    gen_server:start_link(?MODULE, Config, []).

-spec get_status(pid()) -> {ok, map()}.
get_status(Pid) ->
    gen_server:call(Pid, get_status).

-spec halt(pid()) -> ok.
halt(Pid) ->
    gen_server:call(Pid, halt_training).

%% @doc Neuroevolution event handler callback.
%% Called synchronously from neuroevolution_server process.
%% MUST NOT block — sends message to training_proc pid.
-spec handle_event(term(), pid()) -> ok.
handle_event(Event, TrainingPid) ->
    TrainingPid ! {neuro_event, Event},
    ok.

%%--------------------------------------------------------------------
%% Callbacks
%%--------------------------------------------------------------------

init(#{stable_id := StableId} = Config) ->
    PopSize = maps:get(population_size, Config, ?DEFAULT_POPULATION_SIZE),
    MaxGen = maps:get(max_generations, Config, ?DEFAULT_MAX_GENERATIONS),
    OppAF = maps:get(opponent_af, Config, ?DEFAULT_OPPONENT_AF),
    Episodes = maps:get(episodes_per_eval, Config, ?DEFAULT_EPISODES_PER_EVAL),
    SeedNetworks = maps:get(seed_networks, Config, []),
    TrainingConfig = maps:get(training_config, Config, #{}),

    %% Build agent bridge
    {ok, Bridge} = agent_bridge:new(#{
        definition => gladiator_definition,
        sensors => [gladiator_sensor],
        actuators => [gladiator_actuator],
        environment => gladiator_environment,
        evaluator => gladiator_evaluator
    }),

    %% Environment config for headless training (with optional overrides)
    MaxTicks = maps:get(max_ticks, TrainingConfig, ?DEFAULT_MAX_TICKS),
    GladiatorAF = maps:get(gladiator_af, TrainingConfig, 0),
    EnvConfig = #{
        opponent_af => OppAF,
        max_ticks => MaxTicks,
        gladiator_af => GladiatorAF
    },

    %% Build neuro_config via agent_trainer, pass event_handler and seed networks
    {ok, NeuroConfig} = agent_trainer:to_neuro_config(Bridge, EnvConfig, #{
        population_size => PopSize,
        max_generations => MaxGen,
        episodes_per_eval => Episodes,
        event_handler => {?MODULE, self()},
        seed_networks => SeedNetworks
    }),

    %% Start neuroevolution server
    case neuroevolution_server:start_link(NeuroConfig) of
        {ok, NeuroPid} ->
            %% Register in pg group for SSE streaming
            ensure_pg(),
            pg:join(pg, training_group(StableId), self()),

            %% Register by stable_id for lookup
            persistent_term:put({gladiator_training, StableId}, self()),

            %% Record stable in query store
            StartedAt = erlang:system_time(millisecond),
            query_snake_gladiators_store:record_stable(#{
                stable_id => StableId,
                population_size => PopSize,
                max_generations => MaxGen,
                opponent_af => OppAF,
                episodes_per_eval => Episodes,
                started_at => StartedAt
            }),

            %% Start training
            {ok, _} = neuroevolution_server:start_training(NeuroPid),

            logger:info("[gladiator_training] Stable ~s started (pop=~p, gen=~p, af=~p)",
                        [StableId, PopSize, MaxGen, OppAF]),

            %% Broadcast initial status
            broadcast(StableId, #{
                stable_id => StableId,
                status => <<"training">>,
                generation => 0,
                best_fitness => 0.0,
                avg_fitness => 0.0,
                worst_fitness => 0.0,
                running => true
            }),

            {ok, #training{
                stable_id = StableId,
                neuro_pid = NeuroPid,
                max_generations = MaxGen,
                last_generation = 0,
                best_fitness = 0.0,
                avg_fitness = 0.0,
                worst_fitness = 0.0,
                started_at = StartedAt
            }};
        {error, Reason} ->
            {stop, {neuro_start_failed, Reason}}
    end.

handle_call(get_status, _From, #training{stable_id = StableId,
                                          last_generation = Gen,
                                          best_fitness = BestF,
                                          avg_fitness = AvgF,
                                          worst_fitness = WorstF} = State) ->
    {reply, {ok, #{
        stable_id => StableId,
        status => <<"training">>,
        generation => Gen,
        best_fitness => BestF,
        avg_fitness => AvgF,
        worst_fitness => WorstF,
        running => true
    }}, State};

handle_call(halt_training, _From, #training{stable_id = StableId,
                                             neuro_pid = NeuroPid} = State) ->
    neuroevolution_server:stop_training(NeuroPid),
    query_snake_gladiators_store:complete_stable(#{
        stable_id => StableId,
        status => halted
    }),
    broadcast(StableId, #{
        stable_id => StableId,
        status => <<"halted">>,
        running => false
    }),
    logger:info("[gladiator_training] Stable ~s halted by user", [StableId]),
    {stop, normal, ok, State};

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Generation completed — record stats and broadcast
handle_info({neuro_event, {generation_complete, Data}},
            #training{stable_id = StableId} = State) ->
    GenStats = maps:get(generation_stats, Data),
    Gen = GenStats#generation_stats.generation,
    BestF = GenStats#generation_stats.best_fitness,
    AvgF = GenStats#generation_stats.avg_fitness,
    WorstF = GenStats#generation_stats.worst_fitness,

    record_generation_stats(StableId, Gen, BestF, AvgF, WorstF),

    BestEver = max(State#training.best_fitness, BestF),
    update_stable_progress(StableId, Gen, BestEver),

    broadcast(StableId, #{
        stable_id => StableId,
        status => <<"training">>,
        generation => Gen,
        best_fitness => BestF,
        avg_fitness => AvgF,
        worst_fitness => WorstF,
        running => true
    }),

    {noreply, State#training{
        last_generation = Gen,
        best_fitness = BestEver,
        avg_fitness = AvgF,
        worst_fitness = WorstF
    }};

%% Training completed — extract champion, record, stop
handle_info({neuro_event, {training_complete, Data}},
            #training{stable_id = StableId} = State) ->
    BestIndividual = maps:get(best_individual, Data),
    BestFitness = maps:get(best_fitness, Data, 0.0),
    Gen = maps:get(generation, Data, 0),

    NetworkJson = iolist_to_binary(
        json:encode(network_evaluator:to_json(BestIndividual#individual.network))),
    Fitness = BestIndividual#individual.fitness,
    ChampGen = BestIndividual#individual.generation_born,

    query_snake_gladiators_store:record_champion(#{
        stable_id => StableId,
        network_json => NetworkJson,
        fitness => Fitness,
        generation => ChampGen,
        wins => maps:get(wins, BestIndividual#individual.metrics, 0),
        losses => maps:get(losses, BestIndividual#individual.metrics, 0),
        draws => maps:get(draws, BestIndividual#individual.metrics, 0)
    }),

    query_snake_gladiators_store:complete_stable(#{
        stable_id => StableId,
        status => completed
    }),

    broadcast(StableId, #{
        stable_id => StableId,
        status => <<"completed">>,
        generation => Gen,
        best_fitness => BestFitness,
        champion_fitness => Fitness,
        running => false
    }),

    logger:info("[gladiator_training] Stable ~s completed, champion fitness=~.2f",
                [StableId, Fitness]),
    {stop, normal, State};

%% Ignore other neuro events (generation_started, evaluation_progress, etc.)
handle_info({neuro_event, _}, State) ->
    {noreply, State};

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #training{stable_id = StableId, neuro_pid = NeuroPid}) ->
    case is_process_alive(NeuroPid) of
        true ->
            try neuroevolution_server:stop_training(NeuroPid) catch _:_ -> ok end;
        false -> ok
    end,
    persistent_term:erase({gladiator_training, StableId}),
    ok.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

record_generation_stats(StableId, Gen, BestF, AvgF, WorstF) ->
    try
        query_snake_gladiators_store:record_generation(#{
            stable_id => StableId,
            generation => Gen,
            best_fitness => BestF,
            avg_fitness => AvgF,
            worst_fitness => WorstF
        })
    catch
        _:Err ->
            logger:warning("[gladiator_training] Failed to record generation ~p for ~s: ~p",
                           [Gen, StableId, Err])
    end.

update_stable_progress(StableId, Gen, BestFitnessEver) ->
    try
        query_snake_gladiators_store:update_stable_progress(#{
            stable_id => StableId,
            best_fitness => BestFitnessEver,
            generations_completed => Gen
        })
    catch
        _:_ -> ok
    end.

training_group(StableId) ->
    {gladiator_training, StableId}.

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

broadcast(StableId, Msg) ->
    FullMsg = {gladiator_training_state, Msg},
    Members = pg:get_members(pg, training_group(StableId)),
    [Pid ! FullMsg || Pid <- Members, Pid =/= self()].
