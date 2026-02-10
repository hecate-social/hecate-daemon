%%% @doc Application callback for query_plans.
-module(query_plans_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_plans_sup:start_link() of
        {ok, Pid} ->
            ok = query_plans_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
