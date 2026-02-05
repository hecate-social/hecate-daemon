%%% @doc manage_connectors OTP application
%%% Command service for connector lifecycle management (CQRS write side).
%%% Manages Unix socket connectors for local service integration.
-module(manage_connectors_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    manage_connectors_sup:start_link().

stop(_State) ->
    ok.
