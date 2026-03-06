%%% @doc Launcher aggregate state record.

-record(launcher_state, {
    status :: non_neg_integer(),
    groups :: [map()]
}).
