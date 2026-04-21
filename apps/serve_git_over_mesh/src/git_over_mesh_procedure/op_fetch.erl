%%% @doc `fetch` operation — run `git upload-pack --stateless-rpc`.
%%%
%%% `Args` may contain:
%%%   - `stdin` (binary) — the client's ls-refs / fetch request per
%%%     git protocol v2, or legacy upload-request for v0/v1.
%%%   - `service_args` (list of strings) — optional additional flags.
%%%
%%% Returns a map with `ok`, `stdout` (raw pack bytes), and
%%% `exit_status`. Whole-pack transfer — see the module doc in
%%% `git_over_mesh_procedure` for the Phase 2 streaming caveat.
%%% @end
-module(op_fetch).

-export([run/2]).

-define(GIT_BIN, "git").

-spec run(binary(), map()) -> map().
run(RepoId, Args) when is_binary(RepoId), is_map(Args) ->
    Stdin = stdin_blob(Args),
    case locate_git() of
        {ok, Git} ->
            RepoDir = unicode:characters_to_list(repo_paths:repo_dir(RepoId)),
            case filelib:is_dir(RepoDir) of
                true  -> invoke(Git, RepoDir, extra_args(Args), Stdin);
                false -> #{ok => false, error => <<"repo_not_on_disk">>, repo_id => RepoId}
            end;
        {error, Reason} ->
            #{ok => false, error => to_binary(Reason)}
    end.

%%====================================================================
%% Internal
%%====================================================================

invoke(Git, RepoDir, Extra, Stdin) ->
    GitArgs = ["upload-pack", "--stateless-rpc"] ++ Extra ++ [RepoDir],
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

extra_args(Args) ->
    List = case maps:find(service_args, Args) of
               {ok, L} when is_list(L) -> L;
               _ ->
                   case maps:find(<<"service_args">>, Args) of
                       {ok, L} when is_list(L) -> L;
                       _ -> []
                   end
           end,
    [unicode:characters_to_list(E) || E <- List].

locate_git() ->
    case os:find_executable(?GIT_BIN) of
        false -> {error, no_git};
        Path  -> {ok, Path}
    end.

to_binary(B) when is_binary(B) -> B;
to_binary(A) when is_atom(A)   -> atom_to_binary(A, utf8);
to_binary(Other) -> iolist_to_binary(io_lib:format("~p", [Other])).
