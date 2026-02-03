%%% @doc query_capabilities OTP application
%%% Query service for capability discovery (CQRS read side).
-module(query_capabilities_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_capabilities_sup:start_link() of
        {ok, Pid} ->
            %% Initialize SQLite database
            ok = query_capabilities_store:init_schema(),
            %% Subscriptions are handled by query_capabilities_subscriber (started by supervisor)
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
