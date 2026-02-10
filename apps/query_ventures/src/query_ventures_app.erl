%%% @doc query_ventures OTP application
-module(query_ventures_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_ventures_sup:start_link() of
        {ok, Pid} ->
            ok = query_ventures_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
