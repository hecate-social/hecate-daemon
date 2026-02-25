%%% @doc query_llm_mentorships OTP application
%%% QRY service for mentorship read endpoints (stateless).
-module(query_llm_mentorships_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    query_llm_mentorships_sup:start_link().

stop(_State) ->
    ok.
