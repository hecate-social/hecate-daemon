%%% @doc Settings aggregate state record.

-record(settings_state, {
    linux_user     :: binary() | undefined,
    hostname       :: binary() | undefined,
    preferences    :: map(),
    status         :: non_neg_integer(),
    initiated_at   :: integer() | undefined
}).
