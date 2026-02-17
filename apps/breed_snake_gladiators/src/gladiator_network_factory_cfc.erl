%%% @doc CfC network factory for snake gladiators.
%%%
%%% Creates CfC (Closed-form Continuous-time) networks with LTC neurons
%%% in hidden layers. CfC neurons have input-dependent time constants,
%%% enabling temporal reasoning — the snake can adapt its behavior
%%% based on game history, not just current state.
%%%
%%% Hidden layers use tanh activation with CfC dynamics.
%%% Output layer uses linear activation (standard, no CfC).
%%% Uses mutate_cfc/2 for tau and state_bound evolution.
%%% @end
-module(gladiator_network_factory_cfc).

-export([create_feedforward/1, mutate/2, crossover/2]).

-spec create_feedforward({pos_integer(), [pos_integer()], pos_integer()}) -> term().
create_feedforward({InputSize, HiddenLayers, OutputSize}) ->
    network_evaluator:create_cfc_feedforward(InputSize, HiddenLayers, OutputSize, tanh, linear).

-spec mutate(term(), float()) -> term().
mutate(Network, Strength) ->
    network_factory:mutate_cfc(Network, Strength).

-spec crossover(term(), term()) -> term().
crossover(P1, P2) ->
    network_factory:crossover(P1, P2).
