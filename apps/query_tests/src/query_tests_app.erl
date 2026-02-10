%%% @doc Application callback for query_tests.
-module(query_tests_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_tests_sup:start_link() of
        {ok, Pid} ->
            ok = query_tests_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
