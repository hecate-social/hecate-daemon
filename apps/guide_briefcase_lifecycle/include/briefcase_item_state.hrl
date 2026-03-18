-record(briefcase_item_state, {
    item_id     :: binary() | undefined,
    name        :: binary() | undefined,
    kind        :: binary() | undefined,
    parent_id   :: binary() | undefined,
    plugin      :: binary() | undefined,
    file_type   :: binary() | undefined,
    icon        :: binary() | undefined,
    path        :: binary() | undefined,
    mime_type   :: binary() | undefined,
    size        :: non_neg_integer(),
    starred     :: boolean(),
    status      :: non_neg_integer(),
    created_at  :: non_neg_integer() | undefined,
    updated_at  :: non_neg_integer() | undefined
}).
