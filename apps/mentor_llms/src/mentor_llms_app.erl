%%% @doc mentor_llms OTP application
%%% Command service for decentralized LLM learning (CQRS write side).
-module(mentor_llms_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    mentor_llms_sup:start_link().

stop(_State) ->
    ok.
