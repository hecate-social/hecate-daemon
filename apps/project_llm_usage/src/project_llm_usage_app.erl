-module(project_llm_usage_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    project_llm_usage_sup:start_link().

stop(_State) ->
    ok.
