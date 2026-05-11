%%% @doc verify_host_delegation: optional link 5 of the trust chain.
%%%
%%% Only invoked when the verified leaf is a `hosted_address_map'.
%%% Verifies the host_delegation signature against the daemon
%%% pubkey, checks `delegation.realm_pubkey == realm_root_pk',
%%% checks `not_before <= now <= not_after'.
%%%
%%% Phase 0: stub.
%%% @end
-module(verify_host_delegation).

-export([verify/3]).

-spec verify(HostDelegation :: map(),
             DaemonPubkey :: binary(),
             RealmRootPubkey :: binary()) ->
    ok | {error, atom()}.
verify(_HostDelegation, _DaemonPubkey, _RealmRootPubkey) ->
    {error, verify_host_delegation_not_yet_implemented}.
