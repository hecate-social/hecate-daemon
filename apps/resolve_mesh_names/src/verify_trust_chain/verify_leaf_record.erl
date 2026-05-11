%%% @doc verify_leaf_record: link 4 of the 5-link trust chain.
%%%
%%% Verifies a leaf record (station_endpoint, address_pubkey_map,
%%% procedure_advertisement, hosted_address_map) signature against
%%% the member_pubkey from RME; checks no tombstone; checks
%%% `expires_at > now'.
%%%
%%% Phase 0: stub.
%%% @end
-module(verify_leaf_record).

-export([verify/2]).

-spec verify(LeafRecord :: map(), MemberPubkey :: binary()) ->
    {ok, VerifiedLeaf :: map()} | {error, atom()}.
verify(_LeafRecord, _MemberPubkey) ->
    {error, verify_leaf_record_not_yet_implemented}.
