%%% @doc query_mentorships OTP application
%%% Query service for mentorship discovery (CQRS read side).
-module(query_mentorships_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_mentorships_sup:start_link() of
        {ok, Pid} ->
            ok = query_mentorships_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
