%%% @doc fetch_stream — run `git upload-pack --stateless-rpc` and
%%% stream stdout chunks back as raw STREAM_DATA frames.
%%%
%%% See git_over_mesh_stream_procedure for the procedure shape and
%%% the push-not-yet-supported caveat.
-module(op_fetch_stream).

-export([run/3]).

-define(GIT_BIN, "git").
%% Upload-pack on a large repo can take a while to enumerate objects
%% before producing the first chunk. 5 minutes is generous; tighten
%% later if we add backpressure-aware progress signalling.
-define(TIMEOUT_MS, 300000).

-spec run(binary(), pid(), map()) -> ok.
run(RepoId, Stream, Args) when is_binary(RepoId) ->
    Stdin = stdin_blob(Args),
    case locate_git() of
        {ok, Git} ->
            invoke(Git, RepoId, Args, Stdin, Stream);
        {error, Reason} ->
            macula:abort(Stream, <<"no_git">>, to_binary(Reason)),
            ok
    end.

%%====================================================================
%% Internal
%%====================================================================

invoke(Git, RepoId, Args, Stdin, Stream) ->
    RepoDir = unicode:characters_to_list(repo_paths:repo_dir(RepoId)),
    case filelib:is_dir(RepoDir) of
        true ->
            run_git(Git, RepoDir, extra_args(Args), Stdin, Stream);
        false ->
            macula:abort(Stream, <<"repo_not_on_disk">>, RepoId),
            ok
    end.

run_git(Git, RepoDir, Extra, Stdin, Stream) ->
    GitArgs = ["upload-pack", "--stateless-rpc"] ++ Extra ++ [RepoDir],
    Sink = fun(Chunk) -> macula:send(Stream, Chunk) end,
    finalize(port_io_stream:run(Git, GitArgs, Stdin, Sink, ?TIMEOUT_MS),
             Stream).

finalize(#{ok := true}, Stream) ->
    macula:close_stream(Stream),
    ok;
finalize(#{ok := false, exit_status := Status}, Stream) ->
    macula:abort(Stream, <<"upload_pack_failed">>,
                 iolist_to_binary(io_lib:format("git upload-pack exit ~p",
                                                [Status]))),
    ok;
finalize({error, {sink, _Reason}}, _Stream) ->
    %% Caller closed the stream mid-transfer. Nothing to send back; the
    %% port has been closed by port_io_stream. The stream gen_server
    %% will be GC'd when its owner exits.
    ok;
finalize({error, Reason}, Stream) ->
    macula:abort(Stream, <<"port_error">>,
                 iolist_to_binary(io_lib:format("~p", [Reason]))),
    ok.

stdin_blob(#{<<"stdin">> := Bin}) when is_binary(Bin) -> Bin;
stdin_blob(#{stdin := Bin}) when is_binary(Bin) -> Bin;
stdin_blob(_) -> <<>>.

extra_args(#{<<"service_args">> := L}) when is_list(L) -> [to_list(X) || X <- L];
extra_args(#{service_args := L}) when is_list(L) -> [to_list(X) || X <- L];
extra_args(_) -> [].

to_list(B) when is_binary(B) -> binary_to_list(B);
to_list(L) when is_list(L) -> L.

locate_git() ->
    case os:find_executable(?GIT_BIN) of
        false -> {error, git_not_in_path};
        Path  -> {ok, Path}
    end.

to_binary(B) when is_binary(B) -> B;
to_binary(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_binary(L) when is_list(L) -> iolist_to_binary(L).
