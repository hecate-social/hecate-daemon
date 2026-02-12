-module(guide_node_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_node_lifecycle_sup:start_link().

stop(_State) ->
    ok.
