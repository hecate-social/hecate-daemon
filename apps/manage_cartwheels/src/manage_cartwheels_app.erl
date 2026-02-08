%%% @doc manage_cartwheels OTP application
%%% Command service for Cartwheel tracking (CQRS write side).
-module(manage_cartwheels_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    manage_cartwheels_sup:start_link().

stop(_State) ->
    ok.
