%%% @doc Application callback for plan_division.
-module(plan_division_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    plan_division_sup:start_link().

stop(_State) ->
    ok.
