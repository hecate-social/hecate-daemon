%%% @doc query_plugins application behaviour
-module(query_plugins_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    {ok, self()}.

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
