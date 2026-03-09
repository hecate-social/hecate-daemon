%%% @doc Payment aggregate state record.

-record(payment_state, {
    payment_id     :: binary() | undefined,
    consumer_id    :: binary() | undefined,
    procurement_id :: binary() | undefined,
    offering_id    :: binary() | undefined,
    plugin_id      :: binary() | undefined,
    amount_cents   :: non_neg_integer() | undefined,
    currency       :: binary() | undefined,
    status         :: non_neg_integer(),
    initiated_at   :: integer() | undefined,
    archived_at    :: integer() | undefined
}).
