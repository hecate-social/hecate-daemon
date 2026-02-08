%%% @doc manage_torches application behaviour
-module(manage_torches_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    manage_torches_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
