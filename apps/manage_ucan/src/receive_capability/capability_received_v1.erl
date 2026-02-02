%%% @doc Event: A capability was received (granted to one of my identities)
%%% SECURITY-CRITICAL: This enables new actions for my identity
-module(capability_received_v1).
-export([new/9, to_map/1, from_map/1]).

-record(capability_received_v1, {
    capability_id :: binary(),
    issuer :: binary(),
    my_identity :: binary(),
    resource :: binary(),
    actions :: [binary()],
    expires_at :: integer(),
    granted_at :: integer(),
    token_cid :: binary() | undefined,
    recorded_at :: integer()
}).

-opaque capability_received_v1() :: #capability_received_v1{}.
-export_type([capability_received_v1/0]).

-spec new(binary(), binary(), binary(), binary(), [binary()], integer(), integer(), binary() | undefined, integer()) -> capability_received_v1().
new(CapabilityId, Issuer, MyIdentity, Resource, Actions, ExpiresAt, GrantedAt, TokenCid, RecordedAt) ->
    #capability_received_v1{
        capability_id = CapabilityId,
        issuer = Issuer,
        my_identity = MyIdentity,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt,
        token_cid = TokenCid,
        recorded_at = RecordedAt
    }.

-spec to_map(capability_received_v1()) -> map().
to_map(#capability_received_v1{
    capability_id = CapId,
    issuer = Issuer,
    my_identity = MyIdentity,
    resource = Resource,
    actions = Actions,
    expires_at = ExpiresAt,
    granted_at = GrantedAt,
    token_cid = TokenCid,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"capability_received_v1">>,
        capability_id => CapId,
        issuer => Issuer,
        my_identity => MyIdentity,
        resource => Resource,
        actions => Actions,
        expires_at => ExpiresAt,
        granted_at => GrantedAt,
        token_cid => TokenCid,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, capability_received_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    issuer := Issuer,
    my_identity := MyIdentity,
    resource := Resource,
    actions := Actions,
    expires_at := ExpiresAt,
    granted_at := GrantedAt,
    recorded_at := RecordedAt
} = Map) ->
    TokenCid = maps:get(token_cid, Map, undefined),
    {ok, #capability_received_v1{
        capability_id = CapId,
        issuer = Issuer,
        my_identity = MyIdentity,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt,
        token_cid = TokenCid,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_capability_received_event}.
