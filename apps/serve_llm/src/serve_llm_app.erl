%%% @doc serve_llm OTP application
%%% LLM capability service - exposes local inference to API and mesh.
-module(serve_llm_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case application:get_env(serve_llm, enabled, true) of
        true ->
            logger:info("[serve_llm] Starting LLM capability service"),
            serve_llm_sup:start_link();
        false ->
            logger:info("[serve_llm] LLM service disabled"),
            %% Return a dummy supervisor that does nothing
            {ok, spawn_link(fun() -> receive stop -> ok end end)}
    end.

stop(_State) ->
    ok.
