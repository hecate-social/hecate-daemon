%%% @doc LAN machine aggregate state record.
%%% Each machine is identified by its MAC address (stable across IP changes).

-record(lan_machine_state, {
    mac          :: binary() | undefined,   %% e.g., <<"aa:bb:cc:dd:ee:ff">>
    ip           :: binary() | undefined,   %% last known IP
    hostname     :: binary() | undefined,   %% resolved hostname
    interface    :: binary() | undefined,   %% network interface seen on
    ssh          :: boolean(),              %% port 22 open?
    hecate       :: map(),                  %% #{running => bool, version => ..., ...}
    status       :: non_neg_integer(),      %% bit flags
    first_seen   :: integer() | undefined,  %% timestamp of first spot
    last_seen    :: integer() | undefined   %% timestamp of most recent spot
}).
