%%% @doc Event: UCAN capability granted.
-module(ucan_granted_v1).
-export([new/7, to_map/1, from_map/1]).

-record(ucan_granted_v1, {
    capability_id :: binary(),
    issuer :: binary(),
    audience :: binary(),
    resource :: binary(),
    actions :: [binary()],
    expires_at :: integer(),
    granted_at :: integer()
}).

new(CapabilityId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    #ucan_granted_v1{
        capability_id = CapabilityId, issuer = Issuer, audience = Audience,
        resource = Resource, actions = Actions, expires_at = ExpiresAt, granted_at = GrantedAt
    }.

to_map(#ucan_granted_v1{capability_id = C, issuer = I, audience = A, resource = R, actions = Ac, expires_at = E, granted_at = G}) ->
    #{event_type => <<"ucan_granted_v1">>, capability_id => C, issuer => I, audience => A, resource => R, actions => Ac, expires_at => E, granted_at => G}.

from_map(#{capability_id := C, issuer := I, audience := A, resource := R, actions := Ac, expires_at := E, granted_at := G}) ->
    {ok, #ucan_granted_v1{capability_id = C, issuer = I, audience = A, resource = R, actions = Ac, expires_at = E, granted_at = G}};
from_map(_) ->
    {error, invalid_ucan_granted_event}.
