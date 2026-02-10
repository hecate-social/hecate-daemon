-module(guide_venture_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_venture_sup:start_link().

stop(_State) ->
    ok.
