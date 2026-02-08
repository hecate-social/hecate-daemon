%%% @doc query_torches OTP application
%%% Query service for Torches (CQRS read side).
-module(query_torches_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_torches_sup:start_link() of
        {ok, Pid} ->
            ok = query_torches_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
