%%% @doc Application module for discover_lan.
-module(discover_lan_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    discover_lan_sup:start_link().

stop(_State) ->
    ok.
