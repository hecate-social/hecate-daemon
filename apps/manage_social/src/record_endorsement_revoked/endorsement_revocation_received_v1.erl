%%% @doc Event: An endorsement revocation was received
-module(endorsement_revocation_received_v1).
-export([new/5, to_map/1, from_map/1]).

-record(endorsement_revocation_received_v1, {
    endorser_identity :: binary(),
    my_capability_mri :: binary(),
    my_identity :: binary(),
    revoked_at :: integer(),
    recorded_at :: integer()
}).

-opaque endorsement_revocation_received_v1() :: #endorsement_revocation_received_v1{}.
-export_type([endorsement_revocation_received_v1/0]).

-spec new(binary(), binary(), binary(), integer(), integer()) -> endorsement_revocation_received_v1().
new(EndorserIdentity, MyCapabilityMri, MyIdentity, RevokedAt, RecordedAt) ->
    #endorsement_revocation_received_v1{
        endorser_identity = EndorserIdentity,
        my_capability_mri = MyCapabilityMri,
        my_identity = MyIdentity,
        revoked_at = RevokedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(endorsement_revocation_received_v1()) -> map().
to_map(#endorsement_revocation_received_v1{
    endorser_identity = Endorser,
    my_capability_mri = CapMri,
    my_identity = MyIdentity,
    revoked_at = RevokedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"endorsement_revocation_received_v1">>,
        endorser_identity => Endorser,
        my_capability_mri => CapMri,
        my_identity => MyIdentity,
        revoked_at => RevokedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, endorsement_revocation_received_v1()} | {error, term()}.
from_map(#{
    endorser_identity := Endorser,
    my_capability_mri := CapMri,
    my_identity := MyIdentity,
    revoked_at := RevokedAt,
    recorded_at := RecordedAt
}) ->
    {ok, #endorsement_revocation_received_v1{
        endorser_identity = Endorser,
        my_capability_mri = CapMri,
        my_identity = MyIdentity,
        revoked_at = RevokedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_endorsement_revocation_received_event}.
