%%% @doc OTP application module for serve_git_over_mesh.
%%%
%%% Phase 2 of PLAN_GIT_OVER_MESH.md — wires repo-lifecycle events to
%%% on-disk bare repository creation and mesh procedure advertisements.
%%% @end
-module(serve_git_over_mesh_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ok = filelib:ensure_path(repo_paths:root()),
    serve_git_over_mesh_sup:start_link().

stop(_State) ->
    ok.
