%%% @doc Gen_server managing one gladiator training session.
%%%
%%% Owns the neuroevolution_server, polls stats, broadcasts progress
%%% via pg group. SSE stream handlers join the training's pg group
%%% to receive live progress updates.
%%%
%%% Training lifecycle:
%%%   1. start_link(Config) -- builds bridge, starts neuroevolution_server
%%%   2. Polls stats every 2s, broadcasts progress
%%%   3. Records generation stats to query_snake_gladiators_store
%%%   4. On completion: extracts champion, records, stops
%%% @end
-module(training_proc).
-behaviour(gen_server).

-include_lib("faber_neuroevolution/include/neuroevolution.hrl").
-include("gladiator.hrl").

-export([start_link/1, get_status/1, halt/1]).
-export([init/1, handle_info/2, handle_call/3, handle_cast/2, terminate/2]).

-define(POLL_MS, 2000).

-record(training, {
    stable_id      :: binary(),
    neuro_pid      :: pid(),
    max_generations :: non_neg_integer(),
    last_generation :: non_neg_integer(),
    started_at     :: non_neg_integer(),
    timer          :: reference() | undefined
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

%%--------------------------------------------------------------------
%% Callbacks
%%--------------------------------------------------------------------

init(#{stable_id := StableId} = Config) ->
    PopSize = maps:get(population_size, Config, ?DEFAULT_POPULATION_SIZE),
    MaxGen = maps:get(max_generations, Config, ?DEFAULT_MAX_GENERATIONS),
    OppAF = maps:get(opponent_af, Config, ?DEFAULT_OPPONENT_AF),
    Episodes = maps:get(episodes_per_eval, Config, ?DEFAULT_EPISODES_PER_EVAL),

    %% Build agent bridge
    {ok, Bridge} = agent_bridge:new(#{
        definition => gladiator_definition,
        sensors => [gladiator_sensor],
        actuators => [gladiator_actuator],
        environment => gladiator_environment,
        evaluator => gladiator_evaluator
    }),

    %% Environment config for headless training
    EnvConfig = #{
        opponent_af => OppAF,
        max_ticks => ?DEFAULT_MAX_TICKS,
        gladiator_af => 0
    },

    %% Build neuro_config via agent_trainer
    {ok, NeuroConfig} = agent_trainer:to_neuro_config(Bridge, EnvConfig, #{
        population_size => PopSize,
        max_generations => MaxGen,
        episodes_per_eval => Episodes
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

            %% Start polling timer
            Timer = erlang:send_after(?POLL_MS, self(), poll_stats),

            logger:info("[gladiator_training] Stable ~s started (pop=~p, gen=~p, af=~p)",
                        [StableId, PopSize, MaxGen, OppAF]),

            %% Broadcast initial status
            broadcast(StableId, #{
                stable_id => StableId,
                status => <<"training">>,
                generation => 0,
                best_fitness => 0.0,
                avg_fitness => 0.0
            }),

            {ok, #training{
                stable_id = StableId,
                neuro_pid = NeuroPid,
                max_generations = MaxGen,
                last_generation = 0,
                started_at = StartedAt,
                timer = Timer
            }};
        {error, Reason} ->
            {stop, {neuro_start_failed, Reason}}
    end.

handle_call(get_status, _From, #training{stable_id = StableId,
                                          neuro_pid = NeuroPid} = State) ->
    case neuroevolution_server:get_stats(NeuroPid) of
        {ok, Stats} ->
            StatusMap = stats_to_map(StableId, Stats),
            {reply, {ok, StatusMap}, State};
        _ ->
            {reply, {ok, #{stable_id => StableId, status => <<"unknown">>}}, State}
    end;

handle_call(halt_training, _From, #training{stable_id = StableId,
                                             neuro_pid = NeuroPid} = State) ->
    neuroevolution_server:stop_training(NeuroPid),
    query_snake_gladiators_store:complete_stable(#{
        stable_id => StableId,
        status => halted
    }),
    broadcast(StableId, #{
        stable_id => StableId,
        status => <<"halted">>
    }),
    logger:info("[gladiator_training] Stable ~s halted by user", [StableId]),
    {stop, normal, ok, State};

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Poll stats from neuroevolution_server
handle_info(poll_stats, #training{stable_id = StableId,
                                   neuro_pid = NeuroPid,
                                   last_generation = LastGen} = State) ->
    case neuroevolution_server:get_stats(NeuroPid) of
        {ok, Stats} ->
            Running = maps:get(running, Stats, false),
            Generation = maps:get(generation, Stats, 0),

            %% Record new generation stats if generation advanced
            NewLastGen = case Generation > LastGen of
                true ->
                    record_generation_stats(StableId, Stats),
                    update_stable_progress(StableId, Stats),
                    Generation;
                false ->
                    LastGen
            end,

            %% Broadcast progress
            StatusMap = stats_to_map(StableId, Stats),
            broadcast(StableId, StatusMap),

            case Running of
                false ->
                    %% Training completed
                    handle_training_complete(State#training{last_generation = NewLastGen});
                true ->
                    Timer = erlang:send_after(?POLL_MS, self(), poll_stats),
                    {noreply, State#training{last_generation = NewLastGen, timer = Timer}}
            end;
        _ ->
            %% Server might be shutting down
            Timer = erlang:send_after(?POLL_MS, self(), poll_stats),
            {noreply, State#training{timer = Timer}}
    end;

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #training{stable_id = StableId, neuro_pid = NeuroPid,
                              timer = Timer}) ->
    case Timer of
        undefined -> ok;
        Ref -> erlang:cancel_timer(Ref)
    end,
    %% Stop neuroevolution server if still alive
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

handle_training_complete(#training{stable_id = StableId,
                                    neuro_pid = NeuroPid} = State) ->
    %% Extract champion from population
    case neuroevolution_server:get_population(NeuroPid) of
        {ok, Population} when length(Population) > 0 ->
            Champion = find_best_individual(Population),
            NetworkJson = iolist_to_binary(
                json:encode(network_evaluator:to_json(Champion#individual.network))),
            Fitness = Champion#individual.fitness,
            Gen = Champion#individual.generation_born,

            %% Record champion
            query_snake_gladiators_store:record_champion(#{
                stable_id => StableId,
                network_json => NetworkJson,
                fitness => Fitness,
                generation => Gen,
                wins => maps:get(wins, Champion#individual.metrics, 0),
                losses => maps:get(losses, Champion#individual.metrics, 0),
                draws => maps:get(draws, Champion#individual.metrics, 0)
            }),

            query_snake_gladiators_store:complete_stable(#{
                stable_id => StableId,
                status => completed
            }),

            broadcast(StableId, #{
                stable_id => StableId,
                status => <<"completed">>,
                champion_fitness => Fitness
            }),

            logger:info("[gladiator_training] Stable ~s completed, champion fitness=~.2f",
                        [StableId, Fitness]);
        _ ->
            query_snake_gladiators_store:complete_stable(#{
                stable_id => StableId,
                status => completed
            }),
            logger:warning("[gladiator_training] Stable ~s completed with no population",
                           [StableId])
    end,
    {stop, normal, State}.

find_best_individual(Population) ->
    lists:foldl(
        fun(Ind, Best) ->
            case Ind#individual.fitness > Best#individual.fitness of
                true -> Ind;
                false -> Best
            end
        end,
        hd(Population),
        tl(Population)
    ).

record_generation_stats(StableId, Stats) ->
    Gen = maps:get(generation, Stats, 0),
    Best = maps:get(last_gen_best, Stats, 0.0),
    Avg = maps:get(last_gen_avg, Stats, 0.0),
    %% Worst not directly available, use 0.0 as placeholder
    Worst = 0.0,
    try
        query_snake_gladiators_store:record_generation(#{
            stable_id => StableId,
            generation => Gen,
            best_fitness => Best,
            avg_fitness => Avg,
            worst_fitness => Worst
        })
    catch
        _:Err ->
            logger:warning("[gladiator_training] Failed to record generation ~p for ~s: ~p",
                           [Gen, StableId, Err])
    end.

update_stable_progress(StableId, Stats) ->
    BestEver = maps:get(best_fitness_ever, Stats, 0.0),
    Gen = maps:get(generation, Stats, 0),
    try
        query_snake_gladiators_store:update_stable_progress(#{
            stable_id => StableId,
            best_fitness => BestEver,
            generations_completed => Gen
        })
    catch
        _:_ -> ok
    end.

stats_to_map(StableId, Stats) ->
    Running = maps:get(running, Stats, false),
    Status = case Running of
        true -> <<"training">>;
        false -> <<"completed">>
    end,
    #{
        stable_id => StableId,
        status => Status,
        generation => maps:get(generation, Stats, 0),
        best_fitness => maps:get(best_fitness_ever, Stats, 0.0),
        avg_fitness => maps:get(last_gen_avg, Stats, 0.0),
        last_gen_best => maps:get(last_gen_best, Stats, 0.0)
    }.

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
