%%% @doc Phase D share-license bit flags.
%%%
%%% DISTINCT from `license_status.hrl` (appstore/plugin consumer license).
%%% This domain governs cryptographic licenses carrying wrapped CEKs for
%%% file sharing — issued per (file, grantee) tuple, lives in
%%% `share_licenses_store`.

-define(SL_ISSUED,      1).   %% 2^0 Issuer emitted the license
-define(SL_ACCEPTED,    2).   %% 2^1 Recipient unwrapped + sealed CEK
-define(SL_REVOKED,     4).   %% 2^2 Issuer revoked (authority action)
-define(SL_ENDED,       8).   %% 2^3 Recipient observed revoke, unusable
-define(SL_CEK_USABLE, 16).   %% 2^4 Recipient can decrypt (cleared on end)
-define(SL_REWRAPPED,  32).   %% 2^5 Audit: at least one rewrap applied

-define(SL_FLAG_MAP, #{
    1  => <<"Issued">>,
    2  => <<"Accepted">>,
    4  => <<"Revoked">>,
    8  => <<"Ended">>,
    16 => <<"CekUsable">>,
    32 => <<"Rewrapped">>
}).
