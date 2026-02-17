%%% @doc Headless champion duel engine -- runs duels synchronously without
%%% timers, pg groups, or SSE broadcasting.
%%%
%%% Pure-function module for batch-testing champion neural networks against
%%% the heuristic AI. Each duel runs as a tight loop of sensor reads,
%%% network evaluations, actuator conversions, and game ticks.
%%%
%%% Two public functions:
%%%   run/2       - Run a single headless duel, return result map.
%%%   run_batch/3 - Run N duels, return aggregated stats.
%%% @end
-module(headless_champion_duel).

-include_lib("run_snake_duel/include/snake_duel.hrl").
-include("gladiator.hrl").

-export([run/2, run_batch/3]).

-define(MAX_TICKS, 500).

%%--------------------------------------------------------------------
%% @doc Run a single headless duel. Returns a result map.
%%
%% Network must already be compiled (compile_for_nif) or reset
%% (reset_internal_state for CfC). CfC networks are detected via
%% get_neuron_meta and use evaluate_with_state per tick.
%% @end
%%--------------------------------------------------------------------
-spec run(term(), non_neg_integer()) -> map().
run(Network, OpponentAF) ->
    %% Create game: champion (P1, AF=0) vs heuristic (P2, AF=OpponentAF)
    Game0 = snake_duel_engine:create_game(0, OpponentAF),
    Game1 = Game0#game_state{status = running, countdown = 0},

    IsCfC = network_evaluator:get_neuron_meta(Network) =/= undefined,
    run_loop(Game1, Network, IsCfC, 0).

%%--------------------------------------------------------------------
%% @doc Run N headless duels and aggregate results.
%%
%% For CfC networks, reset_internal_state is called before each duel.
%% For standard networks, the same compiled ref is reused.
%% @end
%%--------------------------------------------------------------------
-spec run_batch(term(), non_neg_integer(), pos_integer()) -> map().
run_batch(Network, OpponentAF, NumDuels) ->
    IsCfC = network_evaluator:get_neuron_meta(Network) =/= undefined,
    Results = lists:map(
        fun(_) ->
            Net = case IsCfC of
                true -> network_evaluator:reset_internal_state(Network);
                false -> Network
            end,
            run(Net, OpponentAF)
        end,
        lists:seq(1, NumDuels)
    ),
    aggregate(Results, NumDuels).

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

run_loop(#game_state{status = finished} = Game, _Net, _IsCfC, Tick) ->
    build_result(Game, Tick);
run_loop(_Game, _Net, _IsCfC, Tick) when Tick >= ?MAX_TICKS ->
    %% Timeout -> draw
    #{winner => draw, ticks => Tick, food_eaten => 0, opponent_food => 0,
      wall_kills => false};
run_loop(Game, Net, IsCfC, Tick) ->
    %% Player 1 (champion): neural network evaluation
    Context = #{game => Game},
    Inputs = gladiator_sensor:read(#{player => player1}, Context),
    {Outputs, UpdatedNet} = case IsCfC of
        false ->
            {network_evaluator:evaluate(Net, Inputs), Net};
        true ->
            network_evaluator:evaluate_with_state(Net, Inputs)
    end,
    {ok, {Dir1, Drop1}} = gladiator_actuator:act(Outputs, #{player => player1}, Context),

    %% Player 2 (heuristic AI) -- wall-aware
    #game_state{snake1 = S1, snake2 = S2, food = Food,
                poison_apples = PA, walls = Walls} = Game,
    Dir2 = snake_duel_ai:choose_direction(S2, S1, Food, PA, Walls, player2),
    Drop2 = snake_duel_ai:should_drop_wall(S2, S1, Walls, player2),

    %% Advance game
    Actions = #{drop_tail_1 => Drop1, drop_tail_2 => Drop2},
    Game1 = snake_duel_engine:tick_step(Game, Dir1, Dir2, Actions),

    run_loop(Game1, UpdatedNet, IsCfC, Tick + 1).

build_result(#game_state{winner = Winner, tick = Tick,
                          snake1 = S1, snake2 = S2} = _Game, _LoopTick) ->
    %% Determine if the win was caused by opponent hitting a wall tile
    WallKill = case Winner of
        player1 ->
            %% Check if P2's last event is a wall-related collision
            has_wall_collision(S2#snake.events);
        _ ->
            false
    end,
    #{winner => Winner,
      ticks => Tick,
      food_eaten => S1#snake.score,
      opponent_food => S2#snake.score,
      wall_kills => WallKill}.

has_wall_collision([]) -> false;
has_wall_collision([#game_event{type = collision, value = Val} | _]) ->
    binary:match(Val, <<"wall">>) =/= nomatch;
has_wall_collision([_ | _]) -> false.

aggregate(Results, Total) ->
    {Wins, Losses, Draws, TotalTicks, TotalFood, WallKills} =
        lists:foldl(
            fun(#{winner := W, ticks := T, food_eaten := F, wall_kills := WK},
                {WAcc, LAcc, DAcc, TAcc, FAcc, WKAcc}) ->
                W1 = case W of player1 -> WAcc + 1; _ -> WAcc end,
                L1 = case W of player2 -> LAcc + 1; _ -> LAcc end,
                D1 = case W of draw -> DAcc + 1; _ -> DAcc end,
                WK1 = case WK of true -> WKAcc + 1; false -> WKAcc end,
                {W1, L1, D1, TAcc + T, FAcc + F, WK1}
            end,
            {0, 0, 0, 0, 0, 0},
            Results
        ),
    WinRate = case Total of
        0 -> 0.0;
        _ -> Wins * 100.0 / Total
    end,
    AvgTicks = case Total of
        0 -> 0.0;
        _ -> TotalTicks / Total
    end,
    AvgFood = case Total of
        0 -> 0.0;
        _ -> TotalFood / Total
    end,
    #{wins => Wins,
      losses => Losses,
      draws => Draws,
      total => Total,
      win_rate => round_to(WinRate, 1),
      avg_ticks => round_to(AvgTicks, 1),
      avg_food => round_to(AvgFood, 1),
      wall_kills => WallKills}.

round_to(Value, Decimals) ->
    Factor = math:pow(10, Decimals),
    round(Value * Factor) / Factor.
