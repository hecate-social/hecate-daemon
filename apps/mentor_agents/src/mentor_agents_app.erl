%%% @doc mentor_agents OTP application
%%% Command service for decentralized agent learning (CQRS write side).
-module(mentor_agents_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    mentor_agents_sup:start_link().

stop(_State) ->
    ok.
