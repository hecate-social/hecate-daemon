%%% @doc verify_endorsement: link 3 of the 5-link trust chain.
%%%
%%% Verifies a realm_member_endorsement signature against either
%%% the realm_root_pubkey or any of the trust_delegates from
%%% realm_directory; checks `not_before <= now <= not_after'; checks
%%% no tombstone present.
%%%
%%% Phase 0: stub.
%%% @end
-module(verify_endorsement).

-export([verify/3]).

-spec verify(RmeRecord :: map(),
             RealmRootPubkey :: binary(),
             TrustDelegates :: [binary()]) ->
    {ok, MemberPubkey :: binary()} | {error, atom()}.
verify(_RmeRecord, _RealmRootPubkey, _TrustDelegates) ->
    {error, verify_endorsement_not_yet_implemented}.
