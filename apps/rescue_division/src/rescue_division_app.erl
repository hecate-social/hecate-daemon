%%% @doc Application callback for rescue_division.
-module(rescue_division_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    rescue_division_sup:start_link().

stop(_State) ->
    ok.
