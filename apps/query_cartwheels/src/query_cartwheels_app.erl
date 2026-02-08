%%% @doc query_cartwheels OTP application
%%% Query service for Cartwheels (CQRS read side).
-module(query_cartwheels_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_cartwheels_sup:start_link() of
        {ok, Pid} ->
            ok = query_cartwheels_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
