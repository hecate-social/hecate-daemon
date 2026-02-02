%%% @doc capability_granted_v1 event
%%% Emitted when a UCAN capability is successfully granted.
-module(capability_granted_v1).

-export([new/7, to_map/1, from_map/1]).
-export([get_capability_id/1, get_issuer/1, get_audience/1, get_resource/1,
         get_actions/1, get_expires_at/1, get_granted_at/1]).

-record(capability_granted_v1, {
    capability_id :: binary(),
    issuer :: binary(),
    audience :: binary(),
    resource :: binary(),
    actions :: [binary()],
    expires_at :: integer(),
    granted_at :: integer()
}).

-opaque capability_granted_v1() :: #capability_granted_v1{}.
-export_type([capability_granted_v1/0]).

%% @doc Create a new capability_granted event.
-spec new(binary(), binary(), binary(), binary(), [binary()], integer(), integer()) ->
    capability_granted_v1().
new(CapabilityId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    #capability_granted_v1{
        capability_id = CapabilityId,
        issuer = Issuer,
        audience = Audience,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt
    }.

%% @doc Convert event to map.
-spec to_map(capability_granted_v1()) -> map().
to_map(#capability_granted_v1{
    capability_id = CapId,
    issuer = Issuer,
    audience = Audience,
    resource = Resource,
    actions = Actions,
    expires_at = ExpiresAt,
    granted_at = GrantedAt
}) ->
    #{
        event_type => <<"capability_granted_v1">>,
        capability_id => CapId,
        issuer => Issuer,
        audience => Audience,
        resource => Resource,
        actions => Actions,
        expires_at => ExpiresAt,
        granted_at => GrantedAt
    }.

%% @doc Create event from map.
-spec from_map(map()) -> {ok, capability_granted_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    issuer := Issuer,
    audience := Audience,
    resource := Resource,
    actions := Actions,
    expires_at := ExpiresAt,
    granted_at := GrantedAt
}) ->
    {ok, #capability_granted_v1{
        capability_id = CapId,
        issuer = Issuer,
        audience = Audience,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt
    }};
from_map(_) ->
    {error, invalid_capability_granted_event}.

%% Accessor functions
get_capability_id(#capability_granted_v1{capability_id = C}) -> C.
get_issuer(#capability_granted_v1{issuer = I}) -> I.
get_audience(#capability_granted_v1{audience = A}) -> A.
get_resource(#capability_granted_v1{resource = R}) -> R.
get_actions(#capability_granted_v1{actions = A}) -> A.
get_expires_at(#capability_granted_v1{expires_at = E}) -> E.
get_granted_at(#capability_granted_v1{granted_at = G}) -> G.
