-module(query_ucan_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_ucan_sup:start_link() of
        {ok, Pid} ->
            ok = query_ucan_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
