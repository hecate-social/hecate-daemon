%%% @doc Custom network factory for snake gladiators.
%%%
%%% Creates networks with tanh hidden layers + linear output layer.
%%% Linear outputs allow meaningful magnitude differences between
%%% direction outputs, preventing argmax from picking near-randomly
%%% when all outputs are saturated to similar values.
%%%
%%% Delegates mutation and crossover to the default network_factory.
%%% @end
-module(gladiator_network_factory).

-export([create_feedforward/1, mutate/2, crossover/2]).

-spec create_feedforward({pos_integer(), [pos_integer()], pos_integer()}) -> term().
create_feedforward({InputSize, HiddenLayers, OutputSize}) ->
    network_evaluator:create_feedforward(InputSize, HiddenLayers, OutputSize, tanh, linear).

-spec mutate(term(), float()) -> term().
mutate(Network, Strength) ->
    network_factory:mutate(Network, Strength).

-spec crossover(term(), term()) -> term().
crossover(P1, P2) ->
    network_factory:crossover(P1, P2).
