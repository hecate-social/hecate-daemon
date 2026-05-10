%%% @doc Trust-chain state machine — anchors at a foundation seed,
%%% walks FRTL → realm_directory → endorsement → leaf record (and
%%% optionally host_delegation), verifying every signature and
%%% checking every tombstone gate.
%%%
%%% Phase 0: stub. PLAN_DNS_OVER_MESH_PART1 §4.2 has the full
%%% state-machine table. Each link's verifier lives in its own
%%% module (`verify_frtl', `verify_realm_directory', etc.) so a
%%% future signing-policy change only touches the relevant link.
%%% @end
-module(verify_trust_chain).

-export([verify/2]).

-type leaf() :: map().

-spec verify(Mri :: binary(), LeafType :: atom()) ->
    {ok, leaf()} | {error, atom()}.
verify(_Mri, _LeafType) ->
    {error, verify_trust_chain_not_yet_implemented}.
