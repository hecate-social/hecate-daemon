%%% @doc `push` operation — run `git receive-pack --stateless-rpc`.
%%%
%%% Same constraint as `op_fetch`: whole-pack transfer. The client
%%% sends the full receive-pack request (ref updates + pack) in a
%%% single `stdin` binary; we return `git`'s exit status and its
%%% entire stdout (which is the status-report stream).
%%%
%%% Ref advertisements resulting from the push are reported via the
%%% `announce_ref_updates` listener on the owning node (see the
%%% post-receive hook installed by `git_init_cmd`).
%%% @end
-module(op_push).

-export([run/2]).

-define(GIT_BIN, "git").

-spec run(binary(), map()) -> map().
run(RepoId, Args) when is_binary(RepoId), is_map(Args) ->
    Stdin = stdin_blob(Args),
    case byte_size(Stdin) of
        0 ->
            #{ok => false, error => <<"empty_push_body">>};
        _ ->
            case locate_git() of
                {ok, Git} ->
                    RepoDir = unicode:characters_to_list(repo_paths:repo_dir(RepoId)),
                    case filelib:is_dir(RepoDir) of
                        true  -> invoke(Git, RepoDir, Stdin);
                        false -> #{ok => false, error => <<"repo_not_on_disk">>,
                                   repo_id => RepoId}
                    end;
                {error, Reason} ->
                    #{ok => false, error => to_binary(Reason)}
            end
    end.

%%====================================================================
%% Internal
%%====================================================================

invoke(Git, RepoDir, Stdin) ->
    GitArgs = ["receive-pack", "--stateless-rpc", RepoDir],
    case port_io:run(Git, GitArgs, Stdin) of
        #{ok := _} = Result ->
            Result;
        {error, Reason} ->
            #{ok => false, error => to_binary(Reason)}
    end.

stdin_blob(Args) ->
    case maps:find(stdin, Args) of
        {ok, B} when is_binary(B) -> B;
        _ ->
            case maps:find(<<"stdin">>, Args) of
                {ok, B} when is_binary(B) -> B;
                _ -> <<>>
            end
    end.

locate_git() ->
    case os:find_executable(?GIT_BIN) of
        false -> {error, no_git};
        Path  -> {ok, Path}
    end.

to_binary(B) when is_binary(B) -> B;
to_binary(A) when is_atom(A)   -> atom_to_binary(A, utf8);
to_binary(Other) -> iolist_to_binary(io_lib:format("~p", [Other])).
