-module(gladiator_environment_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("run_snake_duel/include/snake_duel.hrl").
-include("gladiator.hrl").

init_creates_running_game_test() ->
    {ok, EnvState} = gladiator_environment:init(#{}),
    Game = maps:get(game, EnvState),
    ?assertEqual(running, Game#game_state.status),
    ?assertEqual(0, Game#game_state.countdown).

spawn_agent_returns_player1_test() ->
    {ok, EnvState} = gladiator_environment:init(#{}),
    {ok, AgentState, _EnvState2} = gladiator_environment:spawn_agent(agent1, EnvState),
    ?assertEqual(player1, maps:get(player, AgentState)).

tick_is_noop_test() ->
    {ok, EnvState} = gladiator_environment:init(#{}),
    {ok, AgentState, _} = gladiator_environment:spawn_agent(agent1, EnvState),
    {ok, AgentState2, EnvState2} = gladiator_environment:tick(AgentState, EnvState),
    ?assertEqual(AgentState, AgentState2),
    ?assertEqual(EnvState, EnvState2).

apply_action_advances_game_test() ->
    {ok, EnvState} = gladiator_environment:init(#{opponent_af => 30}),
    {ok, AgentState, EnvState2} = gladiator_environment:spawn_agent(agent1, EnvState),
    Game0 = maps:get(game, EnvState2),
    ?assertEqual(0, Game0#game_state.tick),
    {ok, _AgentState2, EnvState3} = gladiator_environment:apply_action(right, AgentState, EnvState2),
    Game1 = maps:get(game, EnvState3),
    ?assertEqual(1, Game1#game_state.tick).

not_terminal_at_start_test() ->
    {ok, EnvState} = gladiator_environment:init(#{}),
    {ok, AgentState, EnvState2} = gladiator_environment:spawn_agent(agent1, EnvState),
    ?assertNot(gladiator_environment:is_terminal(AgentState, EnvState2)).

terminal_at_max_ticks_test() ->
    {ok, EnvState} = gladiator_environment:init(#{max_ticks => 5}),
    {ok, AgentState, EnvState2} = gladiator_environment:spawn_agent(agent1, EnvState),
    %% Advance 5 ticks
    {ok, AS1, ES1} = gladiator_environment:apply_action(right, AgentState, EnvState2),
    {ok, AS2, ES2} = gladiator_environment:apply_action(right, AS1, ES1),
    {ok, AS3, ES3} = gladiator_environment:apply_action(right, AS2, ES2),
    {ok, AS4, ES4} = gladiator_environment:apply_action(right, AS3, ES3),
    {ok, AS5, ES5} = gladiator_environment:apply_action(right, AS4, ES4),
    ?assert(gladiator_environment:is_terminal(AS5, ES5)).

extract_metrics_test() ->
    {ok, EnvState} = gladiator_environment:init(#{}),
    {ok, AgentState, EnvState2} = gladiator_environment:spawn_agent(agent1, EnvState),
    {ok, AgentState2, EnvState3} = gladiator_environment:apply_action(right, AgentState, EnvState2),
    Metrics = gladiator_environment:extract_metrics(AgentState2, EnvState3),
    ?assertEqual(1, maps:get(ticks_survived, Metrics)),
    ?assert(is_integer(maps:get(food_eaten, Metrics))),
    ?assert(is_atom(maps:get(status, Metrics))),
    ?assert(is_atom(maps:get(winner, Metrics))).
