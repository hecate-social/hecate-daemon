-module(query_subscriptions_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_subscriptions_sup:start_link() of
        {ok, Pid} ->
            ok = query_subscriptions_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
