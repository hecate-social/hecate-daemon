%%% @doc Application callback for query_rescues.
-module(query_rescues_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case query_rescues_sup:start_link() of
        {ok, Pid} ->
            ok = query_rescues_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
