%%% @doc State record for a single repo aggregate.
%%%
%%% Stream id convention: `<<"repo-", RepoId/binary>>`.
%%% Status is an integer treated as bit flags — see repo_status.hrl.
%%% @end

-record(repo_state, {
    repo_id        :: binary() | undefined,
    realm          :: binary() | undefined,
    name           :: binary() | undefined,
    owner_did      :: binary() | undefined,
    description    :: binary() | undefined,
    default_branch :: binary() | undefined,
    tags           :: [binary()],
    status         :: non_neg_integer(),   %% bit flags
    initiated_at   :: integer() | undefined,
    revised_at     :: integer() | undefined,
    archived_at    :: integer() | undefined
}).
