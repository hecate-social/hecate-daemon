-record(procurement_state, {
    procurement_id :: binary() | undefined,
    consumer_id    :: binary() | undefined,
    offering_id    :: binary() | undefined,
    plugin_id      :: binary() | undefined,
    author_id      :: binary() | undefined,
    status         :: non_neg_integer(),
    initiated_at   :: integer() | undefined,
    archived_at    :: integer() | undefined
}).
