%%% @doc Application callback for query_deployments.
-module(query_deployments_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_deployments_sup:start_link() of
        {ok, Pid} ->
            ok = query_deployments_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
