%%% @doc revoke_capability_v1 command
%%% Command to revoke a previously granted UCAN capability.
-module(revoke_capability_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_capability_id/1, get_revoker/1, get_revoked_at/1]).

-record(revoke_capability_v1, {
    capability_id :: binary(),
    revoker :: binary(),          % MRI of revoker (must be issuer)
    revoked_at :: integer()
}).

-opaque revoke_capability_v1() :: #revoke_capability_v1{}.
-export_type([revoke_capability_v1/0]).

%% @doc Create a new revoke_capability command.
-spec new(binary(), binary(), integer()) -> revoke_capability_v1().
new(CapabilityId, Revoker, RevokedAt) ->
    #revoke_capability_v1{
        capability_id = CapabilityId,
        revoker = Revoker,
        revoked_at = RevokedAt
    }.

%% @doc Convert command to map.
-spec to_map(revoke_capability_v1()) -> map().
to_map(#revoke_capability_v1{
    capability_id = CapId,
    revoker = Revoker,
    revoked_at = RevokedAt
}) ->
    #{
        capability_id => CapId,
        revoker => Revoker,
        revoked_at => RevokedAt
    }.

%% @doc Create command from map.
-spec from_map(map()) -> {ok, revoke_capability_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    revoker := Revoker,
    revoked_at := RevokedAt
}) ->
    {ok, #revoke_capability_v1{
        capability_id = CapId,
        revoker = Revoker,
        revoked_at = RevokedAt
    }};
from_map(_) ->
    {error, invalid_revoke_capability_command}.

%% Accessor functions
get_capability_id(#revoke_capability_v1{capability_id = C}) -> C.
get_revoker(#revoke_capability_v1{revoker = R}) -> R.
get_revoked_at(#revoke_capability_v1{revoked_at = R}) -> R.
