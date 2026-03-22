%%% @doc Event recording that realm credentials have been encrypted and stored.
%%%
%%% The encrypted_credentials field contains an AES-256-GCM encrypted binary
%%% holding the OAuth credentials map (refresh_token, cert_pem, org_identity).
%%% Only nodes sharing the same Erlang cookie can decrypt.
-module(realm_credentials_secured_v1).

-behaviour(evoq_event).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([event_type/0]).

-record(realm_credentials_secured_v1, {
    membership_id         :: binary(),
    encrypted_credentials :: binary(),
    secured_at            :: integer()
}).

-opaque realm_credentials_secured_v1() :: #realm_credentials_secured_v1{}.
-export_type([realm_credentials_secured_v1/0]).

event_type() -> <<"realm_credentials_secured_v1">>.

-spec new(binary(), binary(), integer()) -> realm_credentials_secured_v1().
new(MembershipId, EncryptedCredentials, SecuredAt) ->
    #realm_credentials_secured_v1{
        membership_id = MembershipId,
        encrypted_credentials = EncryptedCredentials,
        secured_at = SecuredAt
    }.

new(#{membership_id := MId, encrypted_credentials := EncCreds}) ->
    new(MId, EncCreds, erlang:system_time(millisecond)).

-spec to_map(realm_credentials_secured_v1()) -> map().
to_map(#realm_credentials_secured_v1{
    membership_id = MembershipId,
    encrypted_credentials = EncCreds,
    secured_at = SecuredAt
}) ->
    #{
        event_type => <<"realm_credentials_secured_v1">>,
        membership_id => MembershipId,
        encrypted_credentials => EncCreds,
        secured_at => SecuredAt
    }.

-spec from_map(map()) -> {ok, realm_credentials_secured_v1()} | {error, term()}.
from_map(#{membership_id := MId, encrypted_credentials := EncCreds,
           secured_at := At}) ->
    {ok, new(MId, EncCreds, At)};
from_map(#{membership_id := MId, encrypted_credentials := EncCreds}) ->
    {ok, new(MId, EncCreds, 0)};
from_map(_) ->
    {error, invalid_realm_credentials_secured_event}.
