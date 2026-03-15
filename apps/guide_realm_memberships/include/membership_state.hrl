%%% @doc Realm membership aggregate state record.

-record(membership_state, {
    membership_id  :: binary() | undefined,
    realm_id       :: binary() | undefined,
    realm_url      :: binary() | undefined,
    oauth_account  :: binary() | undefined,
    oauth_provider :: binary() | undefined,
    initiated_at   :: integer() | undefined,
    confirmed_at   :: integer() | undefined,
    revoked_at     :: integer() | undefined,
    status         :: non_neg_integer()
}).
