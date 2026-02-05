%%% @doc manage_alc OTP application
%%% Command service for Application Lifecycle tracking (CQRS write side).
-module(manage_alc_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    manage_alc_sup:start_link().

stop(_State) ->
    ok.
