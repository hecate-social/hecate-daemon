%%% @doc OTP application module for guide_repo_lifecycle.
-module(guide_repo_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_repo_lifecycle_sup:start_link().

stop(_State) ->
    ok.
