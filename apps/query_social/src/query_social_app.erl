-module(query_social_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_social_sup:start_link() of
        {ok, Pid} ->
            %% Initialize database schema after supervisor starts
            ok = query_social_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
