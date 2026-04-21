%%% @doc OTP application module for announce_ref_updates.
%%%
%%% Listens on a Unix socket for lines written by bare-repo
%%% post-receive hooks, converts them into mesh FACTs.
%%% @end
-module(announce_ref_updates_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    announce_ref_updates_sup:start_link().

stop(_State) ->
    ok.
