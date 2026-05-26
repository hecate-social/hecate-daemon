%%% @doc Manages the local clone of the hecate-corpus repository.
%%%
%%% hecate-corpus contains philosophy, skills, templates, and roles
%%% used by the daemon and its orchestration layer. This module ensures
%%% the repo is cloned into HECATE_HOME/hecate-corpus/ and provides
%%% convenience paths for consumers.
%%%
%%% ensure/0 is called during daemon startup (non-blocking on failure).
%%% update/0 can be called manually or wired to a timer later.
-module(hecate_agents_repo).

-export([
    ensure/0,
    update/0,
    path/0,
    roles_path/0
]).

%% Codeberg is canonical post-migration; GitHub is a read-only mirror.
-define(REPO_URL, "https://codeberg.org/hecate-social/hecate-corpus.git").
-define(DIR_NAME, "hecate-corpus").

%% @doc Return the local path to the hecate-corpus repo.
-spec path() -> file:filename().
path() ->
    filename:join(shared_paths:hecate_home(), ?DIR_NAME).

%% @doc Return the path to the roles directory inside hecate-corpus.
-spec roles_path() -> file:filename().
roles_path() ->
    filename:join(path(), "roles").

%% @doc Clone hecate-corpus if it does not exist locally.
%% Returns {ok, Path} on success or if already present.
%% Returns {error, Reason} if the clone fails.
-spec ensure() -> {ok, file:filename()} | {error, term()}.
ensure() ->
    RepoPath = path(),
    case filelib:is_dir(filename:join(RepoPath, ".git")) of
        true ->
            logger:info("[hecate-corpus] Repository already present at ~s", [RepoPath]),
            {ok, RepoPath};
        false ->
            clone(RepoPath)
    end.

%% @doc Pull latest changes if the repo is already cloned.
%% Returns ok on success, {error, Reason} on failure.
-spec update() -> ok | {error, term()}.
update() ->
    RepoPath = path(),
    case filelib:is_dir(filename:join(RepoPath, ".git")) of
        true ->
            pull(RepoPath);
        false ->
            logger:warning("[hecate-corpus] Cannot update — repo not cloned at ~s", [RepoPath]),
            {error, not_cloned}
    end.

%%% Internal
%%% ========

clone(RepoPath) ->
    logger:info("[hecate-corpus] Cloning ~s into ~s", [?REPO_URL, RepoPath]),
    Cmd = lists:flatten(io_lib:format(
        "git clone ~s ~s 2>&1 && echo __OK__ || echo __FAIL__",
        [?REPO_URL, RepoPath]
    )),
    Output = os:cmd(Cmd),
    case string:find(Output, "__OK__") of
        nomatch ->
            logger:error(
                "[hecate-corpus] Failed to clone hecate-corpus repository.~n"
                "  Ensure git is installed and network is available.~n"
                "  URL: ~s~n"
                "  Target: ~s~n"
                "  Output: ~s",
                [?REPO_URL, RepoPath, Output]
            ),
            {error, {clone_failed, Output}};
        _ ->
            logger:info("[hecate-corpus] Clone complete at ~s", [RepoPath]),
            {ok, RepoPath}
    end.

pull(RepoPath) ->
    logger:info("[hecate-corpus] Pulling latest changes in ~s", [RepoPath]),
    Cmd = lists:flatten(io_lib:format(
        "git -C ~s pull --ff-only 2>&1 && echo __OK__ || echo __FAIL__",
        [RepoPath]
    )),
    Output = os:cmd(Cmd),
    case string:find(Output, "__OK__") of
        nomatch ->
            logger:error(
                "[hecate-corpus] Failed to pull updates.~n"
                "  Path: ~s~n"
                "  Output: ~s",
                [RepoPath, Output]
            ),
            {error, {pull_failed, Output}};
        _ ->
            logger:info("[hecate-corpus] Updated successfully"),
            ok
    end.
