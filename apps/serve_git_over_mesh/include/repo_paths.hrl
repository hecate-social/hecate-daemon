%%% @doc Shared record/definitions for serve_git_over_mesh.
%%%
%%% Kept intentionally tiny — the interesting logic lives in
%%% `repo_paths.erl`. Header exists so future consumers can
%%% -include_lib() it without pulling a behaviour.
-define(REPO_DIR_SUFFIX, ".git").
