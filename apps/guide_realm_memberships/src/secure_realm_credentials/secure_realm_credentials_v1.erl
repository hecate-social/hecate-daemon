%%% @doc Command to secure realm credentials after OAuth confirmation.
%%%
%%% Carries encrypted OAuth credentials (refresh token, cert, org identity)
%%% for storage in the event store. Credentials are encrypted with
%%% AES-256-GCM using the Erlang cookie as key derivation source.
-module(secure_realm_credentials_v1).

-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(secure_realm_credentials_v1, {
    membership_id       :: binary(),
    encrypted_credentials :: binary()  %% hecate_crypto:encrypt/1 output
}).

-opaque secure_realm_credentials_v1() :: #secure_realm_credentials_v1{}.
-export_type([secure_realm_credentials_v1/0]).

command_type() -> secure_realm_credentials.

%% @doc Create command from map (evoq_command behaviour).
new(#{membership_id := MId, encrypted_credentials := EncCreds}) ->
    {ok, new(MId, EncCreds)};
new(_) ->
    {error, missing_fields}.

%% @doc Create command from membership_id and already-encrypted credentials binary.
-spec new(binary(), binary()) -> secure_realm_credentials_v1().
new(MembershipId, EncryptedCredentials) ->
    #secure_realm_credentials_v1{
        membership_id = MembershipId,
        encrypted_credentials = EncryptedCredentials
    }.

-spec to_map(secure_realm_credentials_v1()) -> map().
to_map(#secure_realm_credentials_v1{
    membership_id = MembershipId,
    encrypted_credentials = EncCreds
}) ->
    #{
        membership_id => MembershipId,
        encrypted_credentials => EncCreds
    }.

-spec from_map(map()) -> {ok, secure_realm_credentials_v1()} | {error, term()}.
from_map(#{membership_id := MId, encrypted_credentials := EncCreds}) ->
    {ok, new(MId, EncCreds)};
from_map(_) ->
    {error, invalid_secure_realm_credentials_command}.
