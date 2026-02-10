%%% @doc Application callback for generate_division.
-module(generate_division_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    generate_division_sup:start_link().

stop(_State) ->
    ok.
