%%% @doc manage_capabilities OTP application
%%% Command service for capability management (CQRS write side).
-module(manage_capabilities_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    manage_capabilities_sup:start_link().

stop(_State) ->
    ok.
