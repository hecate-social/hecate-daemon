%%% @doc OTP application module for query_repos.
-module(query_repos_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    query_repos_sup:start_link().

stop(_State) ->
    ok.
