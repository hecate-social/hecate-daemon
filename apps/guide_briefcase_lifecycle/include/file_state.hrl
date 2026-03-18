%%% @doc File aggregate state record.

-record(file_state, {
    file_id     :: binary() | undefined,
    name        :: binary() | undefined,
    folder_id   :: binary() | undefined,
    file_type   :: binary() | undefined,
    plugin      :: binary() | undefined,
    icon        :: binary() | undefined,
    blob_id     :: binary() | undefined,
    size        :: non_neg_integer(),
    mime_type   :: binary() | undefined,
    starred     :: boolean(),
    status      :: non_neg_integer(),
    created_at  :: non_neg_integer() | undefined,
    updated_at  :: non_neg_integer() | undefined
}).
