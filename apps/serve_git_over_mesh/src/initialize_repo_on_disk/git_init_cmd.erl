%%% @doc `git init --bare` wrapper + post-receive hook installer.
%%%
%%% Idempotent: if the target directory already exists and looks like a
%%% bare repo (HEAD + objects/ + refs/), we skip the init but still
%%% (re)install the post-receive hook — hook contents may have evolved
%%% between daemon releases.
%%% @end
-module(git_init_cmd).

-export([run/3]).

-define(GIT_BIN, "git").

-type run_result() :: {ok, created | exists}
                    | {error, term()}.

-spec run(file:filename(), binary(), binary()) -> run_result().
run(RepoDir, DefaultBranch, RepoId)
  when is_list(RepoDir), is_binary(DefaultBranch), is_binary(RepoId) ->
    case locate_git() of
        {ok, Git} ->
            do_run(Git, RepoDir, DefaultBranch, RepoId);
        {error, _} = Err ->
            Err
    end.

%%====================================================================
%% Internal
%%====================================================================

do_run(Git, RepoDir, DefaultBranch, RepoId) ->
    case looks_like_bare_repo(RepoDir) of
        true ->
            ok = install_hook(RepoDir, RepoId),
            {ok, exists};
        false ->
            case init_bare(Git, RepoDir, DefaultBranch) of
                ok ->
                    ok = install_hook(RepoDir, RepoId),
                    {ok, created};
                {error, _} = Err ->
                    Err
            end
    end.

init_bare(Git, RepoDir, DefaultBranch) ->
    ok = filelib:ensure_path(RepoDir),
    Branch = unicode:characters_to_list(DefaultBranch),
    Args = ["init", "--bare", "--initial-branch=" ++ Branch, RepoDir],
    Port = erlang:open_port({spawn_executable, Git},
                            [{args, Args}, binary, exit_status,
                             stderr_to_stdout, stream]),
    collect(Port, <<>>).

collect(Port, Acc) ->
    receive
        {Port, {data, Chunk}}      -> collect(Port, <<Acc/binary, Chunk/binary>>);
        {Port, {exit_status, 0}}   -> ok;
        {Port, {exit_status, N}}   -> {error, {git_init_failed, N, Acc}}
    after 10000 ->
        catch erlang:port_close(Port),
        {error, git_init_timeout}
    end.

looks_like_bare_repo(Dir) ->
    filelib:is_regular(filename:join(Dir, "HEAD")) andalso
    filelib:is_dir(filename:join(Dir, "objects")) andalso
    filelib:is_dir(filename:join(Dir, "refs")).

install_hook(RepoDir, RepoId) ->
    HooksDir = filename:join(RepoDir, "hooks"),
    ok = filelib:ensure_path(HooksDir),
    HookPath = filename:join(HooksDir, "post-receive"),
    Body = post_receive_script:render(RepoId),
    case file:write_file(HookPath, Body) of
        ok ->
            _ = file:change_mode(HookPath, 8#755),
            ok;
        {error, Reason} ->
            logger:warning("[git_init_cmd] Failed to write hook ~s: ~p",
                           [HookPath, Reason]),
            ok
    end.

locate_git() ->
    case os:find_executable(?GIT_BIN) of
        false  -> {error, no_git};
        Path   -> {ok, Path}
    end.
