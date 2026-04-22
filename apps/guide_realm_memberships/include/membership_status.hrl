%%% @doc Bit flags for realm membership aggregate status.
-ifndef(MEMBERSHIP_STATUS_HRL).
-define(MEMBERSHIP_STATUS_HRL, true).

-define(MEMBERSHIP_INITIATED,      1).  %% 2^0
-define(MEMBERSHIP_CONFIRMED,      2).  %% 2^1
-define(MEMBERSHIP_REVOKED,        4).  %% 2^2 — kept for history; upcasting sets it when reason=:revoked
-define(CREDENTIALS_SECURED,       8).  %% 2^3
-define(REALM_KEY_STORED,         16).  %% 2^4 — K_realm fetched + sealed locally
-define(IDENTITY_PUBKEY_ANNOUNCED, 32).  %% 2^5 — X25519 pubkey announced to realm directory
-define(MEMBERSHIP_RESIGNED,      64).  %% 2^6 — member-initiated departure
-define(MEMBERSHIP_ENDED,        128).  %% 2^7 — terminal (any reason)

-endif.
