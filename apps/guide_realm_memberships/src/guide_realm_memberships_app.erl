%%% @doc Application module for guide_realm_memberships.
-module(guide_realm_memberships_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_realm_memberships_sup:start_link().

stop(_State) ->
    ok.
