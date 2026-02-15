%%% @doc Agent definition for snake gladiator neuroevolution.
%%% Implements the faber_neuroevolution agent_definition behaviour.
-module(gladiator_definition).
-behaviour(agent_definition).

-include("gladiator.hrl").

-export([name/0, version/0, network_topology/0]).

-spec name() -> binary().
name() -> <<"snake_gladiator">>.

-spec version() -> binary().
version() -> <<"1.0.0">>.

-spec network_topology() -> {pos_integer(), [pos_integer()], pos_integer()}.
network_topology() -> ?GLADIATOR_TOPOLOGY.
