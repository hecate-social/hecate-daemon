%%% @doc Path helpers for on-disk bare repositories.
%%%
%%% Resolution order for the root directory:
%%%   1. `{serve_git_over_mesh, [{repo_root, Path}]}` app env (test override)
%%%   2. `shared_paths:base_dir()/repos`
%%% @end
-module(repo_paths).

-include("repo_paths.hrl").

-export([root/0, repo_dir/1, ensure_root/0]).

-spec root() -> file:filename().
root() ->
    case application:get_env(serve_git_over_mesh, repo_root) of
        {ok, Path} -> Path;
        undefined  -> filename:join(shared_paths:base_dir(), "repos")
    end.

-spec repo_dir(binary()) -> file:filename().
repo_dir(RepoId) when is_binary(RepoId) ->
    filename:join(root(), <<RepoId/binary, ?REPO_DIR_SUFFIX>>).

-spec ensure_root() -> ok.
ensure_root() ->
    filelib:ensure_path(root()).
