%%% @doc Command: record a fetched K_realm against a membership.
%%%
%%% Fired by the on_realm_membership_confirmed_fetch_key PM after it
%%% has called io.macula.realm.get_shared_key and re-sealed the
%%% plaintext with hecate_crypto. The command carries only ciphertext
%%% — plaintext K_realm never traverses the aggregate or event log.
%%% @end
-module(store_realm_shared_key_v1).
-behaviour(evoq_command).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([command_type/0]).

-record(store_realm_shared_key_v1, {
    membership_id     :: binary(),
    realm             :: binary(),
    k_realm_version   :: pos_integer(),
    k_realm_encrypted :: binary()
}).

-opaque store_realm_shared_key_v1() :: #store_realm_shared_key_v1{}.
-export_type([store_realm_shared_key_v1/0]).

command_type() -> store_realm_shared_key.

-spec new(map()) -> {ok, store_realm_shared_key_v1()} | {error, term()}.
new(#{membership_id := MId,
      realm := Realm,
      k_realm_version := Version,
      k_realm_encrypted := Encrypted}) ->
    {ok, new(MId, Realm, Version, Encrypted)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary(), pos_integer(), binary()) -> store_realm_shared_key_v1().
new(MembershipId, Realm, Version, Encrypted) ->
    #store_realm_shared_key_v1{
        membership_id     = MembershipId,
        realm             = Realm,
        k_realm_version   = Version,
        k_realm_encrypted = Encrypted
    }.

-spec to_map(store_realm_shared_key_v1()) -> map().
to_map(#store_realm_shared_key_v1{
    membership_id     = MId,
    realm             = Realm,
    k_realm_version   = V,
    k_realm_encrypted = Enc
}) ->
    #{
        membership_id     => MId,
        realm             => Realm,
        k_realm_version   => V,
        k_realm_encrypted => Enc
    }.

-spec from_map(map()) -> {ok, store_realm_shared_key_v1()} | {error, term()}.
from_map(#{membership_id := MId,
           realm := Realm,
           k_realm_version := V,
           k_realm_encrypted := Enc}) ->
    {ok, new(MId, Realm, V, Enc)};
from_map(_) ->
    {error, invalid_store_realm_shared_key_command}.
