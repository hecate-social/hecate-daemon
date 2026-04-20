%%% @doc OTP application module for query_briefcase_files.
-module(query_briefcase_files_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    query_briefcase_files_sup:start_link().

stop(_State) ->
    ok.
