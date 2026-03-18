%%% @doc project_briefcase application behaviour
-module(project_briefcase_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    project_briefcase_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
