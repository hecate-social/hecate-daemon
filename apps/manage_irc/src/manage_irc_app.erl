%%% @doc manage_irc application behaviour
-module(manage_irc_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    manage_irc_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
