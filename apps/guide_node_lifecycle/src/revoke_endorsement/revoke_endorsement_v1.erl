-module(revoke_endorsement_v1).
-export([new/2, to_map/1, from_map/1]).

-record(revoke_endorsement_v1, {
    endorser_identity :: binary(),
    capability_mri :: binary()
}).

-opaque revoke_endorsement_v1() :: #revoke_endorsement_v1{}.
-export_type([revoke_endorsement_v1/0]).

-spec new(binary(), binary()) -> revoke_endorsement_v1().
new(EndorserIdentity, CapabilityMRI) ->
    #revoke_endorsement_v1{
        endorser_identity = EndorserIdentity,
        capability_mri = CapabilityMRI
    }.

-spec to_map(revoke_endorsement_v1()) -> map().
to_map(#revoke_endorsement_v1{endorser_identity = Endorser, capability_mri = MRI}) ->
    #{
        endorser_identity => Endorser,
        capability_mri => MRI
    }.

-spec from_map(map()) -> {ok, revoke_endorsement_v1()} | {error, term()}.
from_map(#{endorser_identity := Endorser, capability_mri := MRI}) ->
    {ok, #revoke_endorsement_v1{endorser_identity = Endorser, capability_mri = MRI}};
from_map(_) ->
    {error, invalid_revoke_endorsement_command}.
