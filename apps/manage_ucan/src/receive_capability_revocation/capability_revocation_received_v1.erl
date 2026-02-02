%%% @doc Event: A capability revocation was received
%%% SECURITY-CRITICAL: This must immediately invalidate the capability
-module(capability_revocation_received_v1).
-export([new/5, to_map/1, from_map/1]).

-record(capability_revocation_received_v1, {
    capability_id :: binary(),
    my_identity :: binary(),
    revoker :: binary(),
    revoked_at :: integer(),
    recorded_at :: integer()
}).

-opaque capability_revocation_received_v1() :: #capability_revocation_received_v1{}.
-export_type([capability_revocation_received_v1/0]).

-spec new(binary(), binary(), binary(), integer(), integer()) -> capability_revocation_received_v1().
new(CapabilityId, MyIdentity, Revoker, RevokedAt, RecordedAt) ->
    #capability_revocation_received_v1{
        capability_id = CapabilityId,
        my_identity = MyIdentity,
        revoker = Revoker,
        revoked_at = RevokedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(capability_revocation_received_v1()) -> map().
to_map(#capability_revocation_received_v1{
    capability_id = CapId,
    my_identity = MyIdentity,
    revoker = Revoker,
    revoked_at = RevokedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"capability_revocation_received_v1">>,
        capability_id => CapId,
        my_identity => MyIdentity,
        revoker => Revoker,
        revoked_at => RevokedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, capability_revocation_received_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    my_identity := MyIdentity,
    revoker := Revoker,
    revoked_at := RevokedAt,
    recorded_at := RecordedAt
}) ->
    {ok, #capability_revocation_received_v1{
        capability_id = CapId,
        my_identity = MyIdentity,
        revoker = Revoker,
        revoked_at = RevokedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_capability_revocation_received_event}.
