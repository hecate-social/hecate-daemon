%%% @doc Command: Record that a capability I received was revoked
%%% Triggered by mesh listener when ucan.revoked fact affects my capabilities
%%% SECURITY-CRITICAL: This disables actions I could previously perform
-module(receive_capability_revocation_v1).
-export([new/4, to_map/1, from_map/1]).

-record(receive_capability_revocation_v1, {
    capability_id :: binary(),
    my_identity :: binary(),
    revoker :: binary(),             %% Who revoked it (usually the issuer)
    revoked_at :: integer()
}).

-opaque receive_capability_revocation_v1() :: #receive_capability_revocation_v1{}.
-export_type([receive_capability_revocation_v1/0]).

-spec new(binary(), binary(), binary(), integer()) -> receive_capability_revocation_v1().
new(CapabilityId, MyIdentity, Revoker, RevokedAt) ->
    #receive_capability_revocation_v1{
        capability_id = CapabilityId,
        my_identity = MyIdentity,
        revoker = Revoker,
        revoked_at = RevokedAt
    }.

-spec to_map(receive_capability_revocation_v1()) -> map().
to_map(#receive_capability_revocation_v1{
    capability_id = CapId,
    my_identity = MyIdentity,
    revoker = Revoker,
    revoked_at = RevokedAt
}) ->
    #{
        capability_id => CapId,
        my_identity => MyIdentity,
        revoker => Revoker,
        revoked_at => RevokedAt
    }.

-spec from_map(map()) -> {ok, receive_capability_revocation_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    my_identity := MyIdentity,
    revoker := Revoker,
    revoked_at := RevokedAt
}) ->
    {ok, #receive_capability_revocation_v1{
        capability_id = CapId,
        my_identity = MyIdentity,
        revoker = Revoker,
        revoked_at = RevokedAt
    }};
from_map(_) ->
    {error, invalid_receive_capability_revocation_command}.
