%%% @doc Sale aggregate state record.

-record(sale_state, {
    sale_id        :: binary() | undefined,
    seller_id      :: binary() | undefined,
    procurement_id :: binary() | undefined,
    offering_id    :: binary() | undefined,
    plugin_id      :: binary() | undefined,
    status         :: non_neg_integer(),
    initiated_at   :: integer() | undefined,
    archived_at    :: integer() | undefined
}).
