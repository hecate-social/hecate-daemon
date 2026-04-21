%%% @doc `describe` operation — returns repo metadata.
%%%
%%% Looks the repo up in `project_repos_store` (ETS read model) and
%%% returns a compact map for the client. Includes the on-disk
%%% `size_bytes` so thin clients can choose partial-clone filters.
%%% @end
-module(op_describe).

-export([run/1]).

-spec run(binary()) -> map().
run(RepoId) when is_binary(RepoId) ->
    case project_repos_store:get(RepoId) of
        {ok, Entry} ->
            RepoDir = repo_paths:repo_dir(RepoId),
            #{
                ok             => true,
                repo_id        => RepoId,
                name           => maps:get(name, Entry, RepoId),
                description    => maps:get(description, Entry, <<>>),
                default_branch => maps:get(default_branch, Entry, <<"main">>),
                owner_did      => maps:get(owner_did, Entry, <<>>),
                tags           => maps:get(tags, Entry, []),
                status         => maps:get(status, Entry, <<"active">>),
                visibility     => maps:get(visibility, Entry, <<"private">>),
                size_bytes     => dir_size(RepoDir)
            };
        {error, not_found} ->
            #{ok => false, error => <<"repo_not_found">>, repo_id => RepoId}
    end.

%%====================================================================
%% Internal
%%====================================================================

dir_size(Dir) ->
    case filelib:is_dir(Dir) of
        false -> 0;
        true ->
            filelib:fold_files(Dir, ".*", true,
                               fun(F, Acc) ->
                                   Acc + filelib:file_size(F)
                               end, 0)
    end.
