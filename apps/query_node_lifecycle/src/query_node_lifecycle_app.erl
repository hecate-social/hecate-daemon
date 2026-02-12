-module(query_node_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    query_node_lifecycle_sup:start_link().

stop(_State) ->
    ok.
