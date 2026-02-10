%%% @doc Application callback for query_monitoring.
-module(query_monitoring_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_monitoring_sup:start_link() of
        {ok, Pid} ->
            ok = query_monitoring_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
