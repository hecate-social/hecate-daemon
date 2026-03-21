-module(project_site_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    project_site_sup:start_link().

stop(_State) ->
    ok.
