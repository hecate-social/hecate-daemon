%%% @doc Event: K_realm stored against a membership (ciphertext only).
%%%
%%% Fat event — projection does not need to re-read aggregate state.
%%% Bumps the membership's status with the REALM_KEY_STORED bit.
%%% @end
-module(realm_shared_key_stored_v1).
-behaviour(evoq_event).

-export([new/1, new/5, to_map/1, from_map/1]).
-export([event_type/0]).

-record(realm_shared_key_stored_v1, {
    membership_id     :: binary(),
    realm             :: binary(),
    k_realm_version   :: pos_integer(),
    k_realm_encrypted :: binary(),
    received_at       :: integer()
}).

-opaque realm_shared_key_stored_v1() :: #realm_shared_key_stored_v1{}.
-export_type([realm_shared_key_stored_v1/0]).

event_type() -> <<"realm_shared_key_stored_v1">>.

-spec new(map()) -> {ok, realm_shared_key_stored_v1()}.
new(#{membership_id := MId,
      realm := Realm,
      k_realm_version := V,
      k_realm_encrypted := Enc} = Params) ->
    ReceivedAt = maps:get(received_at, Params, erlang:system_time(millisecond)),
    {ok, new(MId, Realm, V, Enc, ReceivedAt)}.

-spec new(binary(), binary(), pos_integer(), binary(), integer()) -> realm_shared_key_stored_v1().
new(MembershipId, Realm, Version, Encrypted, ReceivedAt) ->
    #realm_shared_key_stored_v1{
        membership_id     = MembershipId,
        realm             = Realm,
        k_realm_version   = Version,
        k_realm_encrypted = Encrypted,
        received_at       = ReceivedAt
    }.

-spec to_map(realm_shared_key_stored_v1()) -> map().
to_map(#realm_shared_key_stored_v1{
    membership_id     = MId,
    realm             = Realm,
    k_realm_version   = V,
    k_realm_encrypted = Enc,
    received_at       = At
}) ->
    #{
        event_type        => event_type(),
        membership_id     => MId,
        realm             => Realm,
        k_realm_version   => V,
        k_realm_encrypted => Enc,
        received_at       => At
    }.

-spec from_map(map()) -> {ok, realm_shared_key_stored_v1()} | {error, term()}.
from_map(#{membership_id := MId,
           realm := Realm,
           k_realm_version := V,
           k_realm_encrypted := Enc,
           received_at := At}) ->
    {ok, new(MId, Realm, V, Enc, At)};
from_map(_) ->
    {error, invalid_realm_shared_key_stored_event}.
