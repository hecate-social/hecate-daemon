%%% @doc verify_frtl: link 1 of the 5-link trust chain.
%%%
%%% Verifies the foundation_realm_trust_list signature against the
%%% known foundation_pubkey, checks `not_after > now + grace', and
%%% returns the realm-pubkey lookup table.
%%%
%%% Phase 0: stub. Phase 1 wires macula_record + macula_identity
%%% verification.
%%% @end
-module(verify_frtl).

-export([verify/2]).

%% @doc Verify an FRTL record against a foundation pubkey.
-spec verify(FrtlRecord :: map(), FoundationPubkey :: binary()) ->
    {ok, RealmTable :: map()} | {error, atom()}.
verify(_FrtlRecord, _FoundationPubkey) ->
    {error, verify_frtl_not_yet_implemented}.
