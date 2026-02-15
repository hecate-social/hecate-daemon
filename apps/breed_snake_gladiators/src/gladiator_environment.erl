%%% @doc Environment for snake gladiator neuroevolution.
%%%
%%% Wraps snake_duel_engine as a headless (no timers, no pg, no SSE)
%%% training environment. The gladiator is always player1; the opponent
%%% is the heuristic AI (player2) with configurable asshole factor.
%%%
%%% The game advances in apply_action/3 via snake_duel_engine:tick_step/3.
%%% tick/2 is a no-op since the game clock is driven by actions.
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

    Game0 = snake_duel_engine:create_game(GladiatorAF, OpponentAF),
    Game1 = Game0#game_state{status = running, countdown = 0},

    EnvState = #{
        game => Game1,
        opponent_af => OpponentAF,
        max_ticks => MaxTicks
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
apply_action(GladiatorDir, AgentState, #{game := Game} = EnvState) ->
    %% Opponent uses heuristic AI
    #game_state{snake2 = S2, snake1 = S1,
                food = Food, poison_apples = PA} = Game,
    OpponentDir = snake_duel_ai:choose_direction(S2, S1, Food, PA, player2),

    %% Advance game: gladiator = player1 (Dir1), opponent = player2 (Dir2)
    Game1 = snake_duel_engine:tick_step(Game, GladiatorDir, OpponentDir),
    {ok, AgentState, EnvState#{game := Game1}}.

-spec is_terminal(map(), map()) -> boolean().
is_terminal(_AgentState, #{game := Game, max_ticks := MaxTicks}) ->
    Game#game_state.status =:= finished orelse Game#game_state.tick >= MaxTicks.

-spec extract_metrics(map(), map()) -> map().
extract_metrics(_AgentState, #{game := Game}) ->
    #game_state{snake1 = S1, status = Status, winner = Winner,
                tick = Ticks} = Game,
    #{
        ticks_survived => Ticks,
        food_eaten => S1#snake.score,
        status => Status,
        winner => Winner
    }.
