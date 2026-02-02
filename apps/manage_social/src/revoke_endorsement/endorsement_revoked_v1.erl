-module(endorsement_revoked_v1).
-export([new/3, to_map/1, from_map/1]).

-record(endorsement_revoked_v1, {
    endorser_identity :: binary(),
    capability_mri :: binary(),
    revoked_at :: integer()
}).

-opaque endorsement_revoked_v1() :: #endorsement_revoked_v1{}.
-export_type([endorsement_revoked_v1/0]).

-spec new(binary(), binary(), integer()) -> endorsement_revoked_v1().
new(EndorserIdentity, CapabilityMRI, RevokedAt) ->
    #endorsement_revoked_v1{
        endorser_identity = EndorserIdentity,
        capability_mri = CapabilityMRI,
        revoked_at = RevokedAt
    }.

-spec to_map(endorsement_revoked_v1()) -> map().
to_map(#endorsement_revoked_v1{
    endorser_identity = Endorser,
    capability_mri = MRI,
    revoked_at = RevokedAt
}) ->
    #{
        event_type => <<"endorsement_revoked_v1">>,
        endorser_identity => Endorser,
        capability_mri => MRI,
        revoked_at => RevokedAt
    }.

-spec from_map(map()) -> {ok, endorsement_revoked_v1()} | {error, term()}.
from_map(#{
    endorser_identity := Endorser,
    capability_mri := MRI,
    revoked_at := RevokedAt
}) ->
    {ok, #endorsement_revoked_v1{
        endorser_identity = Endorser,
        capability_mri = MRI,
        revoked_at = RevokedAt
    }};
from_map(_) ->
    {error, invalid_endorsement_revoked_event}.
