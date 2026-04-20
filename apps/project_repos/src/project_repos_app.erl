%%% @doc OTP application module for project_repos.
-module(project_repos_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    project_repos_sup:start_link().

stop(_State) ->
    ok.
