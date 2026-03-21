%%% @doc Site aggregate state record.
%%% Site = identity + nodes. Realm memberships are separate aggregates
%%% in the same store (site_store).

-record(site_state, {
    site_id        :: binary() | undefined,
    nodes          :: map(),          %% #{NodeName => #{admitted_at => integer()}}
    status         :: non_neg_integer(),
    initiated_at   :: integer() | undefined
}).
