%%% @doc Bit flags for realm membership aggregate status.
-ifndef(MEMBERSHIP_STATUS_HRL).
-define(MEMBERSHIP_STATUS_HRL, true).

-define(MEMBERSHIP_INITIATED,      1).  %% 2^0
-define(MEMBERSHIP_CONFIRMED,      2).  %% 2^1
-define(MEMBERSHIP_REVOKED,        4).  %% 2^2
-define(CREDENTIALS_SECURED,       8).  %% 2^3
-define(REALM_KEY_STORED,         16).  %% 2^4 — K_realm fetched + sealed locally
-define(IDENTITY_PUBKEY_ANNOUNCED, 32).  %% 2^5 — X25519 pubkey announced to realm directory

-endif.
