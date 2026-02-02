-module(manage_social_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    manage_social_sup:start_link().

stop(_State) ->
    ok.
