%%% @doc State record for a single briefcase-file aggregate.
%%%
%%% Stream id convention: `<<"briefcase-", FileId/binary>>`.
%%% Status is an integer treated as bit flags — see briefcase_status.hrl.
%%% @end

-record(briefcase_state, {
    file_id       :: binary() | undefined,
    realm         :: binary() | undefined,
    path          :: binary() | undefined,   %% current path in the virtual tree
    mime_type     :: binary() | undefined,
    size          :: non_neg_integer() | undefined,
    content_hash  :: binary() | undefined,   %% BLAKE3 of plaintext
    chunk_hashes  :: [binary()],             %% BLAKE3 per chunk (empty in v1 whole-file)
    author_did    :: binary() | undefined,
    status        :: non_neg_integer(),      %% bit flags
    uploaded_at   :: integer() | undefined,
    revised_at    :: integer() | undefined
}).
