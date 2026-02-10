%%% @doc Application callback for query_generations.
-module(query_generations_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_generations_sup:start_link() of
        {ok, Pid} ->
            ok = query_generations_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
