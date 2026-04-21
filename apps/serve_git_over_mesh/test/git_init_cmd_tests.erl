%%% @doc EUnit tests for `git_init_cmd:run/3`.
%%%
%%% Uses a tempdir as the bare-repo target and asserts the directory
%%% layout plus executable post-receive hook.
-module(git_init_cmd_tests).

-include_lib("eunit/include/eunit.hrl").

init_and_hook_test_() ->
    case os:find_executable("git") of
        false ->
            [{"git missing — skipping", ?_assert(true)}];
        _ ->
            {setup,
             fun setup/0,
             fun teardown/1,
             fun(Dir) ->
                 [
                     creates_bare_layout(Dir),
                     reinit_is_idempotent(Dir),
                     installs_executable_hook(Dir)
                 ]
             end}
    end.

setup() ->
    TmpBase = filename:join("/tmp",
        "git-init-" ++ os:getpid() ++ "-"
            ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(TmpBase),
    TmpBase.

teardown(Dir) ->
    os:cmd("rm -rf " ++ Dir),
    ok.

%% ===================================================================
%% Cases
%% ===================================================================

creates_bare_layout(Base) ->
    fun() ->
        RepoDir = filename:join(Base, "r1.git"),
        ?assertEqual({ok, created},
                     git_init_cmd:run(RepoDir, <<"main">>, <<"r1">>)),
        ?assert(filelib:is_regular(filename:join(RepoDir, "HEAD"))),
        ?assert(filelib:is_dir(filename:join(RepoDir, "objects"))),
        ?assert(filelib:is_dir(filename:join(RepoDir, "refs")))
    end.

reinit_is_idempotent(Base) ->
    fun() ->
        RepoDir = filename:join(Base, "r2.git"),
        ?assertEqual({ok, created},
                     git_init_cmd:run(RepoDir, <<"main">>, <<"r2">>)),
        ?assertEqual({ok, exists},
                     git_init_cmd:run(RepoDir, <<"main">>, <<"r2">>))
    end.

installs_executable_hook(Base) ->
    fun() ->
        RepoDir = filename:join(Base, "r3.git"),
        ?assertMatch({ok, _},
                     git_init_cmd:run(RepoDir, <<"main">>, <<"r3">>)),
        HookPath = filename:join([RepoDir, "hooks", "post-receive"]),
        ?assert(filelib:is_regular(HookPath)),
        {ok, FileInfo} = file:read_file_info(HookPath, [{time, posix}]),
        %% file_info record — use the mode field explicitly.
        Mode = element(8, FileInfo),
        ?assert(Mode band 8#100 =/= 0),
        {ok, Body} = file:read_file(HookPath),
        ?assert(binary:match(Body, <<"REPO_ID=\"r3\"">>) =/= nomatch)
    end.
