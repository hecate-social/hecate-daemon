%%% @doc verify_realm_directory: link 2 of the 5-link trust chain.
%%%
%%% Verifies the realm_directory signature against the
%%% realm_root_pubkey from FRTL, checks no tombstone present,
%%% checks version is current, returns the directory's
%%% trust_delegates + coverage_proof_pointer.
%%%
%%% Phase 0: stub.
%%% @end
-module(verify_realm_directory).

-export([verify/2]).

-spec verify(DirRecord :: map(), RealmRootPubkey :: binary()) ->
    {ok, DirContent :: map()} | {error, atom()}.
verify(_DirRecord, _RealmRootPubkey) ->
    {error, verify_realm_directory_not_yet_implemented}.
