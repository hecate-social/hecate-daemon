%%% @doc query_alc OTP application
%%% Query service for ALC projects (CQRS read side).
-module(query_alc_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_alc_sup:start_link() of
        {ok, Pid} ->
            ok = query_alc_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
