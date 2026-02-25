%%% @doc project_llm_mentorships OTP application
%%% PRJ service for mentorship read models (SQLite store + projections).
-module(project_llm_mentorships_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    project_llm_mentorships_sup:start_link().

stop(_State) ->
    ok.
