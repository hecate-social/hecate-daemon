%%% @doc Environment for snake gladiator neuroevolution.
%%%
%%% Wraps snake_duel_engine as a headless (no timers, no pg, no SSE)
%%% training environment. The gladiator is always player1; the opponent
%%% is the heuristic AI (player2) with configurable asshole factor.
%%%
%%% The game advances in apply_action/3 via snake_duel_engine:tick_step/3.
%%% tick/2 is a no-op since the game clock is driven by actions.
%%%
%%% Tracks additional metrics for enhanced fitness:
%%%   - food_proximity_delta: cumulative change in distance to food
%%%   - opponent_crashed: whether opponent hit a wall/body
%%%   - positions_revisited: count of positions visited more than once
%%% @end
-module(gladiator_environment).
-behaviour(agent_environment).

-include_lib("run_snake_duel/include/snake_duel.hrl").
-include("gladiator.hrl").

-export([name/0, init/1, spawn_agent/2, tick/2, apply_action/3,
         is_terminal/2, extract_metrics/2]).

-spec name() -> binary().
name() -> <<"snake_duel_arena">>.

-spec init(map()) -> {ok, map()}.
init(Config) ->
    OpponentAF = maps:get(opponent_af, Config, ?DEFAULT_OPPONENT_AF),
    MaxTicks = maps:get(max_ticks, Config, ?DEFAULT_MAX_TICKS),
    GladiatorAF = maps:get(gladiator_af, Config, 0),
    FitnessWeights = maps:get(fitness_weights, Config, ?DEFAULT_FITNESS_WEIGHTS),

    Game0 = snake_duel_engine:create_game(GladiatorAF, OpponentAF),
    Game1 = Game0#game_state{status = running, countdown = 0},

    EnvState = #{
        game => Game1,
        opponent_af => OpponentAF,
        max_ticks => MaxTicks,
        fitness_weights => FitnessWeights,
        food_proximity_delta => 0.0,
        prev_food_dist => food_distance(Game1),
        positions_visited => #{},
        positions_revisited => 0
    },
    {ok, EnvState}.

-spec spawn_agent(term(), map()) -> {ok, map(), map()}.
spawn_agent(_AgentId, EnvState) ->
    AgentState = #{player => player1},
    {ok, AgentState, EnvState}.

-spec tick(map(), map()) -> {ok, map(), map()}.
tick(AgentState, EnvState) ->
    %% No-op: game advances in apply_action/3
    {ok, AgentState, EnvState}.

-spec apply_action(term(), map(), map()) -> {ok, map(), map()}.
apply_action({GladiatorDir, GladiatorDrop}, AgentState, EnvState) ->
    apply_action_impl(GladiatorDir, GladiatorDrop, AgentState, EnvState);
apply_action(GladiatorDir, AgentState, EnvState) when is_atom(GladiatorDir) ->
    %% Backward compat: bare atom direction (no drop)
    apply_action_impl(GladiatorDir, false, AgentState, EnvState).

apply_action_impl(GladiatorDir, GladiatorDrop, AgentState, #{game := Game} = EnvState) ->
    %% Opponent uses heuristic AI (wall-aware)
    #game_state{snake2 = S2, snake1 = S1,
                food = Food, poison_apples = PA, walls = Walls} = Game,
    OpponentDir = snake_duel_ai:choose_direction(S2, S1, Food, PA, Walls, player2),
    OpponentDrop = snake_duel_ai:should_drop_wall(S2, S1, Walls, player2),

    %% Advance game with explicit actions
    Actions = #{drop_tail_1 => GladiatorDrop, drop_tail_2 => OpponentDrop},
    Game1 = snake_duel_engine:tick_step(Game, GladiatorDir, OpponentDir, Actions),

    %% Track food proximity delta
    PrevDist = maps:get(prev_food_dist, EnvState),
    CurrDist = food_distance(Game1),
    Delta = PrevDist - CurrDist, %% positive = got closer
    AccDelta = maps:get(food_proximity_delta, EnvState) + Delta,

    %% Track position revisiting (circle detection)
    #game_state{snake1 = NewS1} = Game1,
    [HeadPos | _] = NewS1#snake.body,
    Visited = maps:get(positions_visited, EnvState),
    VisitCount = maps:get(HeadPos, Visited, 0),
    Revisited = maps:get(positions_revisited, EnvState),
    NewRevisited = case VisitCount of
        0 -> Revisited;
        _ -> Revisited + 1
    end,

    %% Track wall kills (opponent died from wall tile collision)
    PrevWallKills = maps:get(wall_kills, EnvState, 0),
    WallKills = case Game1#game_state.status of
        finished ->
            case Game1#game_state.winner of
                player1 ->
                    %% Check if opponent hit a wall tile
                    [OppHead | _] = (Game1#game_state.snake2)#snake.body,
                    WallPositions = sets:from_list([W#wall_tile.pos || W <- Game1#game_state.walls]),
                    case sets:is_element(OppHead, WallPositions) of
                        true -> PrevWallKills + 1;
                        false -> PrevWallKills
                    end;
                _ -> PrevWallKills
            end;
        _ -> PrevWallKills
    end,

    EnvState1 = EnvState#{
        game := Game1,
        food_proximity_delta := AccDelta,
        prev_food_dist := CurrDist,
        positions_visited := Visited#{HeadPos => VisitCount + 1},
        positions_revisited := NewRevisited,
        wall_kills => WallKills
    },
    {ok, AgentState, EnvState1}.

-spec is_terminal(map(), map()) -> boolean().
is_terminal(_AgentState, #{game := Game, max_ticks := MaxTicks}) ->
    Game#game_state.status =:= finished orelse Game#game_state.tick >= MaxTicks.

-spec extract_metrics(map(), map()) -> map().
extract_metrics(_AgentState, #{game := Game} = EnvState) ->
    #game_state{snake1 = S1, snake2 = S2, status = Status,
                winner = Winner, tick = Ticks} = Game,

    %% Determine if opponent crashed (hit wall/body, not timeout)
    OpponentCrashed = (Winner =:= player1) andalso (Status =:= finished)
        andalso (Ticks < maps:get(max_ticks, EnvState)),

    #{
        ticks_survived => Ticks,
        food_eaten => S1#snake.score,
        status => Status,
        winner => Winner,
        food_proximity_delta => maps:get(food_proximity_delta, EnvState),
        opponent_crashed => OpponentCrashed,
        positions_revisited => maps:get(positions_revisited, EnvState),
        unique_positions => map_size(maps:get(positions_visited, EnvState)),
        opponent_score => S2#snake.score,
        wall_kills => maps:get(wall_kills, EnvState, 0),
        fitness_weights => maps:get(fitness_weights, EnvState, ?DEFAULT_FITNESS_WEIGHTS)
    }.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

%% Manhattan distance from snake1 head to food.
food_distance(#game_state{snake1 = #snake{body = [{Hx, Hy} | _]},
                          food = {Fx, Fy}}) ->
    abs(Fx - Hx) + abs(Fy - Hy) + 0.0. %% + 0.0 forces float
