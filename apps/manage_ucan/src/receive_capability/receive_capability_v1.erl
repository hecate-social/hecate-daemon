%%% @doc Command: Record that someone granted a capability TO one of my identities
%%% Triggered by mesh listener when ucan.granted fact targets MY_IDENTITIES
%%% SECURITY-CRITICAL: These are capabilities I can use to perform actions
-module(receive_capability_v1).
-export([new/8, to_map/1, from_map/1]).

-record(receive_capability_v1, {
    capability_id :: binary(),
    issuer :: binary(),              %% Who granted the capability
    my_identity :: binary(),         %% Which of my identities received it
    resource :: binary(),            %% What resource this grants access to
    actions :: [binary()],           %% What actions are permitted
    expires_at :: integer(),         %% When the capability expires
    granted_at :: integer(),         %% When it was granted
    token_cid :: binary() | undefined  %% Content ID of the UCAN token
}).

-opaque receive_capability_v1() :: #receive_capability_v1{}.
-export_type([receive_capability_v1/0]).

-spec new(binary(), binary(), binary(), binary(), [binary()], integer(), integer(), binary() | undefined) -> receive_capability_v1().
new(CapabilityId, Issuer, MyIdentity, Resource, Actions, ExpiresAt, GrantedAt, TokenCid) ->
    #receive_capability_v1{
        capability_id = CapabilityId,
        issuer = Issuer,
        my_identity = MyIdentity,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt,
        token_cid = TokenCid
    }.

-spec to_map(receive_capability_v1()) -> map().
to_map(#receive_capability_v1{
    capability_id = CapId,
    issuer = Issuer,
    my_identity = MyIdentity,
    resource = Resource,
    actions = Actions,
    expires_at = ExpiresAt,
    granted_at = GrantedAt,
    token_cid = TokenCid
}) ->
    #{
        capability_id => CapId,
        issuer => Issuer,
        my_identity => MyIdentity,
        resource => Resource,
        actions => Actions,
        expires_at => ExpiresAt,
        granted_at => GrantedAt,
        token_cid => TokenCid
    }.

-spec from_map(map()) -> {ok, receive_capability_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    issuer := Issuer,
    my_identity := MyIdentity,
    resource := Resource,
    actions := Actions,
    expires_at := ExpiresAt,
    granted_at := GrantedAt
} = Map) ->
    TokenCid = maps:get(token_cid, Map, undefined),
    {ok, #receive_capability_v1{
        capability_id = CapId,
        issuer = Issuer,
        my_identity = MyIdentity,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt,
        token_cid = TokenCid
    }};
from_map(_) ->
    {error, invalid_receive_capability_command}.
