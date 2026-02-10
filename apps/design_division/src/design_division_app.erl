%%% @doc Application callback for design_division.
-module(design_division_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    design_division_sup:start_link().

stop(_State) ->
    ok.
