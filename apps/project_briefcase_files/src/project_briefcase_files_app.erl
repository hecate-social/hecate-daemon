%%% @doc OTP application module for project_briefcase_files.
-module(project_briefcase_files_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    project_briefcase_files_sup:start_link().

stop(_State) ->
    ok.
