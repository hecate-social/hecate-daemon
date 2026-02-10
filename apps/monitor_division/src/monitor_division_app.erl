%%% @doc Application callback for monitor_division.
-module(monitor_division_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    monitor_division_sup:start_link().

stop(_State) ->
    ok.
