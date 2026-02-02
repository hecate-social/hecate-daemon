-module(manage_ucan_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    manage_ucan_sup:start_link().

stop(_State) ->
    ok.
