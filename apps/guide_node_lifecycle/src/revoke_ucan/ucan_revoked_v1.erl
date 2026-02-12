-module(ucan_revoked_v1).
-export([new/3, to_map/1, from_map/1]).

-record(ucan_revoked_v1, {
    capability_id :: binary(),
    revoker :: binary(),
    revoked_at :: integer()
}).

new(CapabilityId, Revoker, RevokedAt) ->
    #ucan_revoked_v1{capability_id = CapabilityId, revoker = Revoker, revoked_at = RevokedAt}.

to_map(#ucan_revoked_v1{capability_id = C, revoker = R, revoked_at = At}) ->
    #{event_type => <<"ucan_revoked_v1">>, capability_id => C, revoker => R, revoked_at => At}.

from_map(#{capability_id := C, revoker := R, revoked_at := At}) ->
    {ok, #ucan_revoked_v1{capability_id = C, revoker = R, revoked_at = At}};
from_map(_) ->
    {error, invalid_ucan_revoked_event}.
