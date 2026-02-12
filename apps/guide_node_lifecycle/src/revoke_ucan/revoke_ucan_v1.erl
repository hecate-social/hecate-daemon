-module(revoke_ucan_v1).
-export([new/3, to_map/1, from_map/1]).

-record(revoke_ucan_v1, {
    capability_id :: binary(),
    revoker :: binary(),
    revoked_at :: integer()
}).

new(CapabilityId, Revoker, RevokedAt) ->
    #revoke_ucan_v1{capability_id = CapabilityId, revoker = Revoker, revoked_at = RevokedAt}.

to_map(#revoke_ucan_v1{capability_id = C, revoker = R, revoked_at = At}) ->
    #{capability_id => C, revoker => R, revoked_at => At}.

from_map(#{capability_id := C, revoker := R, revoked_at := At}) ->
    {ok, #revoke_ucan_v1{capability_id = C, revoker = R, revoked_at = At}};
from_map(_) ->
    {error, invalid_revoke_ucan_command}.
