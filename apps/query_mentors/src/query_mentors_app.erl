%%% @doc query_mentors OTP application
%%% Query service for mentor/learning discovery (CQRS read side).
-module(query_mentors_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_mentors_sup:start_link() of
        {ok, Pid} ->
            ok = query_mentors_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
