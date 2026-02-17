%%% @doc Gen_server managing a champion-vs-AI duel match.
%%%
%%% Like duel_proc in run_snake_duel, but player 1 is a neural network
%%% loaded from a champion's network_json, evaluated each tick via
%%% gladiator_sensor/actuator. Player 2 is the heuristic AI.
%%%
%%% Registers in the same pg group convention ({snake_duel, MatchId})
%%% so the existing stream_duel_api SSE endpoint works unchanged.
%%%
%%% Lifecycle:
%%%   1. start_link(Config) -- loads champion network, creates game
%%%   2. Countdown phase (3, 2, 1, GO) at 800ms intervals
%%%   3. Game ticks: P1=neural network, P2=heuristic AI
%%%   4. On collision/game-over: broadcasts final state, stops
%%% @end
-module(gladiator_duel_proc).
-behaviour(gen_server).

-include_lib("run_snake_duel/include/snake_duel.hrl").
-include("gladiator.hrl").

-export([start_link/1]).
-export([init/1, handle_info/2, handle_call/3, handle_cast/2, terminate/2]).

-define(COUNTDOWN_MS, 800).

-record(gduel, {
    match_id    :: binary(),
    game        :: game_state(),
    tick_ms     :: non_neg_integer(),
    network     :: term(),          %% compiled network from champion
    opponent_af :: non_neg_integer(),
    started_at  :: non_neg_integer(),
    timer       :: reference() | undefined
}).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------

-spec start_link(map()) -> {ok, pid()} | {error, term()}.
start_link(Config) ->
    gen_server:start_link(?MODULE, Config, []).

%%--------------------------------------------------------------------
%% Callbacks
%%--------------------------------------------------------------------

init(#{match_id := MatchId, network := Network} = Config) ->
    OppAF = maps:get(opponent_af, Config, 50),
    TickMs = maps:get(tick_ms, Config, ?DEFAULT_TICK_MS),

    %% Compile network for fast NIF evaluation (standard networks only).
    %% CfC networks skip NIF compilation — they use evaluate_with_state
    %% which maintains internal state and isn't compatible with compiled refs.
    CompiledNet = case network_evaluator:get_neuron_meta(Network) of
        undefined -> network_evaluator:compile_for_nif(Network);
        _CfcMeta -> network_evaluator:reset_internal_state(Network)
    end,

    %% Create game: champion (P1, AF=0) vs heuristic (P2, AF=OppAF)
    Game0 = snake_duel_engine:create_game(0, OppAF),
    Game1 = Game0#game_state{status = countdown},

    %% Register in pg group for SSE streaming (same convention as duel_proc)
    ensure_pg(),
    pg:join(pg, duel_group(MatchId), self()),
    persistent_term:put({snake_duel, MatchId}, self()),

    %% Start countdown
    Timer = erlang:send_after(?COUNTDOWN_MS, self(), countdown_tick),
    StartedAt = erlang:system_time(millisecond),

    logger:info("[gladiator_duel] Match ~s started (opponent_af=~p, tick=~pms)",
                [MatchId, OppAF, TickMs]),

    %% Broadcast initial state
    broadcast(MatchId, Game1),

    {ok, #gduel{match_id = MatchId, game = Game1, tick_ms = TickMs,
                network = CompiledNet, opponent_af = OppAF,
                started_at = StartedAt, timer = Timer}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Countdown tick — final
handle_info(countdown_tick, #gduel{game = #game_state{countdown = 1} = Game,
                                    match_id = MatchId, tick_ms = TickMs} = State) ->
    Game1 = Game#game_state{countdown = 0, status = running},
    broadcast(MatchId, Game1),
    Timer = erlang:send_after(TickMs, self(), game_tick),
    {noreply, State#gduel{game = Game1, timer = Timer}};

%% Countdown tick — counting
handle_info(countdown_tick, #gduel{game = #game_state{countdown = N} = Game,
                                    match_id = MatchId} = State) when N > 1 ->
    Game1 = Game#game_state{countdown = N - 1},
    broadcast(MatchId, Game1),
    Timer = erlang:send_after(?COUNTDOWN_MS, self(), countdown_tick),
    {noreply, State#gduel{game = Game1, timer = Timer}};

%% Game tick — neural network vs heuristic AI
handle_info(game_tick, #gduel{game = Game0, match_id = MatchId,
                               tick_ms = TickMs, network = Net} = State) ->
    %% Player 1 (champion): neural network evaluation
    %% CfC networks use evaluate_with_state (returns updated network with new internal state)
    %% Standard networks use evaluate (stateless)
    Context = #{game => Game0},
    Inputs = gladiator_sensor:read(#{player => player1}, Context),
    {Outputs, UpdatedNet} = case network_evaluator:get_neuron_meta(Net) of
        undefined ->
            {network_evaluator:evaluate(Net, Inputs), Net};
        _CfcMeta ->
            network_evaluator:evaluate_with_state(Net, Inputs)
    end,
    {ok, {Dir1, Drop1}} = gladiator_actuator:act(Outputs, #{player => player1}, Context),

    %% Player 2 (heuristic AI) — wall-aware
    #game_state{snake1 = S1, snake2 = S2, food = Food,
                poison_apples = PA, walls = Walls} = Game0,
    Dir2 = snake_duel_ai:choose_direction(S2, S1, Food, PA, Walls, player2),
    Drop2 = snake_duel_ai:should_drop_wall(S2, S1, Walls, player2),

    %% Advance game with explicit directions and wall actions
    Actions = #{drop_tail_1 => Drop1, drop_tail_2 => Drop2},
    Game1 = snake_duel_engine:tick_step(Game0, Dir1, Dir2, Actions),
    broadcast(MatchId, Game1),

    case Game1#game_state.status of
        finished ->
            logger:info("[gladiator_duel] Match ~s finished, winner=~p",
                        [MatchId, Game1#game_state.winner]),
            {stop, normal, State#gduel{game = Game1, network = UpdatedNet, timer = undefined}};
        _ ->
            Timer = erlang:send_after(TickMs, self(), game_tick),
            {noreply, State#gduel{game = Game1, network = UpdatedNet, timer = Timer}}
    end;

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #gduel{match_id = MatchId, timer = Timer, network = Net}) ->
    case Timer of
        undefined -> ok;
        Ref -> erlang:cancel_timer(Ref)
    end,
    %% Strip NIF ref to prevent memory leak
    network_evaluator:strip_compiled_ref(Net),
    persistent_term:erase({snake_duel, MatchId}),
    ok.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

duel_group(MatchId) ->
    {snake_duel, MatchId}.

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

broadcast(MatchId, Game) ->
    Msg = {snake_duel_state, duel_proc:game_to_map(MatchId, Game)},
    Members = pg:get_members(pg, duel_group(MatchId)),
    [Pid ! Msg || Pid <- Members, Pid =/= self()].
