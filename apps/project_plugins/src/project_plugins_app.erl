%%% @doc project_plugins application behaviour
-module(project_plugins_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    project_plugins_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
