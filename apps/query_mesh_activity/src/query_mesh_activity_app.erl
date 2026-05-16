-module(query_mesh_activity_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    query_mesh_activity_sup:start_link().

stop(_State) -> ok.
