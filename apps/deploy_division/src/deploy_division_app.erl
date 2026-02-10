%%% @doc Application callback for deploy_division.
-module(deploy_division_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    deploy_division_sup:start_link().

stop(_State) ->
    ok.
