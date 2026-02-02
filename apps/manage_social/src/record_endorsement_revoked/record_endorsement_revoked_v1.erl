%%% @doc Command: Record that someone revoked their endorsement of my capability
-module(record_endorsement_revoked_v1).
-export([new/4, to_map/1, from_map/1]).

-record(record_endorsement_revoked_v1, {
    endorser_identity :: binary(),
    my_capability_mri :: binary(),
    my_identity :: binary(),
    revoked_at :: integer()
}).

-opaque record_endorsement_revoked_v1() :: #record_endorsement_revoked_v1{}.
-export_type([record_endorsement_revoked_v1/0]).

-spec new(binary(), binary(), binary(), integer()) -> record_endorsement_revoked_v1().
new(EndorserIdentity, MyCapabilityMri, MyIdentity, RevokedAt) ->
    #record_endorsement_revoked_v1{
        endorser_identity = EndorserIdentity,
        my_capability_mri = MyCapabilityMri,
        my_identity = MyIdentity,
        revoked_at = RevokedAt
    }.

-spec to_map(record_endorsement_revoked_v1()) -> map().
to_map(#record_endorsement_revoked_v1{
    endorser_identity = Endorser,
    my_capability_mri = CapMri,
    my_identity = MyIdentity,
    revoked_at = RevokedAt
}) ->
    #{
        endorser_identity => Endorser,
        my_capability_mri => CapMri,
        my_identity => MyIdentity,
        revoked_at => RevokedAt
    }.

-spec from_map(map()) -> {ok, record_endorsement_revoked_v1()} | {error, term()}.
from_map(#{
    endorser_identity := Endorser,
    my_capability_mri := CapMri,
    my_identity := MyIdentity,
    revoked_at := RevokedAt
}) ->
    {ok, #record_endorsement_revoked_v1{
        endorser_identity = Endorser,
        my_capability_mri = CapMri,
        my_identity = MyIdentity,
        revoked_at = RevokedAt
    }};
from_map(_) ->
    {error, invalid_record_endorsement_revoked_command}.
