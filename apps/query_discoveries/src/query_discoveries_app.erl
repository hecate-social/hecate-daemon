%%% @doc Application callback for query_discoveries.
-module(query_discoveries_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_discoveries_sup:start_link() of
        {ok, Pid} ->
            ok = query_discoveries_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
