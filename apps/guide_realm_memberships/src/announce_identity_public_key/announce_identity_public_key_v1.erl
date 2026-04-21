%%% @doc Command: announce this daemon's X25519 encryption pubkey to the
%%% realm directory.
%%%
%%% Fired once per realm, after `realm_shared_key_stored_v1` confirms
%%% the daemon is fully a member. The announcement populates the realm
%%% server's DID→pubkey directory, enabling other members to wrap CEKs
%%% for this daemon's identity (DID-scope license issuance).
%%% @end
-module(announce_identity_public_key_v1).
-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).

-record(announce_identity_public_key_v1, {
    membership_id           :: binary(),
    mri                     :: binary(),
    encryption_public_key   :: binary()
}).

-opaque announce_identity_public_key_v1() :: #announce_identity_public_key_v1{}.
-export_type([announce_identity_public_key_v1/0]).

command_type() -> announce_identity_public_key.

new(#{membership_id := MId,
      mri := Mri,
      encryption_public_key := Pub}) ->
    {ok, new(MId, Mri, Pub)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary(), binary()) -> announce_identity_public_key_v1().
new(MembershipId, Mri, Pub) ->
    #announce_identity_public_key_v1{
        membership_id = MembershipId,
        mri = Mri,
        encryption_public_key = Pub
    }.

to_map(#announce_identity_public_key_v1{
    membership_id = MId, mri = Mri, encryption_public_key = Pub
}) ->
    #{
        membership_id => MId,
        mri => Mri,
        encryption_public_key => Pub
    }.

from_map(#{membership_id := MId,
           mri := Mri,
           encryption_public_key := Pub}) ->
    {ok, new(MId, Mri, Pub)};
from_map(_) ->
    {error, invalid_announce_identity_public_key_command}.
