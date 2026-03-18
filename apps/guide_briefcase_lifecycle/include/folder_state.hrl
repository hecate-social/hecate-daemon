%%% @doc Folder aggregate state record.

-record(folder_state, {
    folder_id   :: binary() | undefined,
    name        :: binary() | undefined,
    parent_id   :: binary() | undefined,
    icon        :: binary() | undefined,
    status      :: non_neg_integer(),
    created_at  :: non_neg_integer() | undefined,
    updated_at  :: non_neg_integer() | undefined
}).
