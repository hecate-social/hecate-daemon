%%% @doc Application callback for query_designs.
-module(query_designs_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_designs_sup:start_link() of
        {ok, Pid} ->
            ok = query_designs_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
