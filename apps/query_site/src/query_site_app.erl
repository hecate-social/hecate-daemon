-module(query_site_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    query_site_sup:start_link().

stop(_State) ->
    ok.
