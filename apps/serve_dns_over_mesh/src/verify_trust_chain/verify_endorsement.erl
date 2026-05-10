%%% @doc Verifier for the `endorsement' link in the trust chain. Phase 0
%%% stub — see PLAN_DNS_OVER_MESH_PART1 §4 for the per-link
%%% signature + freshness rules.
%%% @end
-module(verify_endorsement).

-export([verify/2]).

-spec verify(Record :: map(), TrustAnchor :: term()) ->
    {ok, map()} | {error, atom()}.
verify(_Record, _TrustAnchor) ->
    {error, verify_endorsement_not_yet_implemented}.
