%%% @doc EUnit for op_fetch_stream.
%%%
%%% Drives the handler against macula_stream_local (Phase 1 dispatch
%%% path) so we exercise the streaming SDK + the upload-pack pipe
%%% without needing a live mesh. Creates a small bare repo with one
%%% commit, then opens a streaming fetch and reassembles the pack.
-module(op_fetch_stream_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PROC, <<"test.git.fetch_stream">>).

setup() ->
    {ok, _} = application:ensure_all_started(macula),
    case os:find_executable("git") of
        false ->
            skip;
        _ ->
            TmpDir = filename:join(["/tmp",
                                    "gom_stream_test_" ++
                                    integer_to_list(
                                      erlang:unique_integer([positive]))]),
            ok = filelib:ensure_path(TmpDir),
            OldHome = os:getenv("HECATE_HOME"),
            os:putenv("HECATE_HOME", TmpDir),
            RepoId = make_test_repo(TmpDir),
            [macula:unadvertise_stream(P)
             || {P, _} <- macula_stream_local:list_advertised()],
            ok = macula:advertise_stream(?PROC, server_stream,
                    fun(Stream, Args) ->
                        git_over_mesh_stream_procedure:handle(
                          RepoId, Stream, Args)
                    end),
            {TmpDir, OldHome, RepoId}
    end.

teardown(skip) -> ok;
teardown({TmpDir, OldHome, _RepoId}) ->
    [macula:unadvertise_stream(P)
     || {P, _} <- macula_stream_local:list_advertised()],
    case OldHome of
        false -> os:unsetenv("HECATE_HOME");
        _ -> os:putenv("HECATE_HOME", OldHome)
    end,
    _ = file:del_dir_r(TmpDir),
    ok.

with_setup(Tests) ->
    {setup, fun setup/0, fun teardown/1, Tests}.

%%% ===================================================================
%%% Tests
%%% ===================================================================

ls_refs_streams_test_() ->
    with_setup([
        {"ls-refs request streams a non-empty advertisement",
         fun() ->
             case macula_stream_local:list_advertised() of
                 [] -> ?debugMsg("git not installed; skipping");
                 _ ->
                     %% pkt-line v2 ls-refs request
                     Req = ls_refs_request(),
                     {ok, S} = macula:call_stream(?PROC,
                         #{<<"op">> => <<"fetch">>,
                           <<"stdin">> => Req,
                           <<"service_args">> =>
                               ["--http-backend-info-refs"]}),
                     %% Drain — we accept any non-empty body. Ref
                     %% encoding details are git's; we test transport.
                     Bytes = drain(S, <<>>),
                     ?assert(byte_size(Bytes) > 0)
             end
         end}
    ]).

unsupported_op_test_() ->
    with_setup([
        {"op=push aborts with unsupported_op",
         fun() ->
             case macula_stream_local:list_advertised() of
                 [] -> ?debugMsg("git not installed; skipping");
                 _ ->
                     {ok, S} = macula:call_stream(?PROC,
                         #{<<"op">> => <<"push">>}),
                     ?assertMatch({error, {<<"unsupported_op">>, _}},
                                  macula:recv(S, 1000))
             end
         end}
    ]).

missing_repo_test_() ->
    %% This test creates its own advertisement against a non-existent
    %% repo_id, bypassing the shared setup which uses a real one.
    {setup,
     fun() ->
         {ok, _} = application:ensure_all_started(macula),
         [macula:unadvertise_stream(P)
          || {P, _} <- macula_stream_local:list_advertised()],
         BogusId = <<"01HZY00000000000000000ABSENT">>,
         Proc = <<"test.git.absent.fetch_stream">>,
         ok = macula:advertise_stream(Proc, server_stream,
                fun(Stream, Args) ->
                    git_over_mesh_stream_procedure:handle(
                      BogusId, Stream, Args)
                end),
         {BogusId, Proc}
     end,
     fun({_BogusId, Proc}) ->
         macula:unadvertise_stream(Proc)
     end,
     fun({_BogusId, Proc}) ->
         [{"missing repo aborts with repo_not_on_disk",
           fun() ->
               {ok, S} = macula:call_stream(Proc,
                   #{<<"op">> => <<"fetch">>, <<"stdin">> => <<>>}),
               ?assertMatch({error, {<<"repo_not_on_disk">>, _}},
                            macula:recv(S, 1000))
           end}]
     end}.

%%% ===================================================================
%%% Helpers
%%% ===================================================================

drain(Stream, Acc) ->
    case macula:recv(Stream, 5000) of
        {chunk, Bin} -> drain(Stream, <<Acc/binary, Bin/binary>>);
        eof -> Acc;
        Other -> erlang:error({unexpected, Other})
    end.

%% Pkt-line v2 ls-refs request. Format: 4-hex-digit length + payload.
ls_refs_request() ->
    pkt_line(<<"command=ls-refs\n">>) ,
    iolist_to_binary([
        pkt_line(<<"command=ls-refs\n">>),
        pkt_line(<<"agent=git/2.43.0\n">>),
        delim_pkt(),
        pkt_line(<<"peel\n">>),
        pkt_line(<<"symrefs\n">>),
        flush_pkt()
    ]).

pkt_line(Body) ->
    Len = byte_size(Body) + 4,
    Hex = io_lib:format("~4.16.0b", [Len]),
    iolist_to_binary([Hex, Body]).

delim_pkt() -> <<"0001">>.
flush_pkt() -> <<"0000">>.

%% Build a one-commit bare repo on disk at the path repo_paths uses
%% for RepoId. Returns the chosen RepoId.
make_test_repo(_TmpDir) ->
    RepoId = <<"01HZY0123456789ABCDEFTESTREPO">>,
    BareDir = unicode:characters_to_list(repo_paths:repo_dir(RepoId)),
    ok = filelib:ensure_path(filename:dirname(BareDir)),
    %% git init --bare creates the dir
    0 = run_git(["init", "--bare", "--initial-branch=main", BareDir]),
    %% Need at least one commit for ls-refs to return a ref.
    %% Create a workdir, commit, push to bare.
    WorkDir = BareDir ++ "_work",
    ok = filelib:ensure_path(WorkDir),
    0 = run_git(["init", "--initial-branch=main", WorkDir]),
    0 = run_git_in(WorkDir, ["config", "user.email", "test@example.com"]),
    0 = run_git_in(WorkDir, ["config", "user.name", "Test"]),
    ok = file:write_file(filename:join(WorkDir, "README"), <<"hi">>),
    0 = run_git_in(WorkDir, ["add", "README"]),
    0 = run_git_in(WorkDir, ["commit", "-m", "init"]),
    0 = run_git_in(WorkDir, ["remote", "add", "origin", BareDir]),
    0 = run_git_in(WorkDir, ["push", "origin", "main"]),
    RepoId.

run_git(Args) ->
    Cmd = string:join(["git" | Args], " "),
    %% Use os:cmd then check output is empty/short — for tests we
    %% only care about exit status, derived via $?
    Output = os:cmd(Cmd ++ " 2>&1; echo __EXIT__$?"),
    parse_exit_marker(Output).

run_git_in(Cwd, Args) ->
    Cmd = "cd " ++ Cwd ++ " && " ++ string:join(["git" | Args], " "),
    Output = os:cmd(Cmd ++ " 2>&1; echo __EXIT__$?"),
    parse_exit_marker(Output).

parse_exit_marker(Output) ->
    case re:run(Output, "__EXIT__(\\d+)", [{capture, all_but_first, list}]) of
        {match, [N]} -> list_to_integer(N);
        _ -> 1
    end.
