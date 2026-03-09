%%% @doc project_license_offerings application behaviour
-module(project_license_offerings_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    project_license_offerings_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
