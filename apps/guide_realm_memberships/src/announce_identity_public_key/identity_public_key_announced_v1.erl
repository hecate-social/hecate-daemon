%%% @doc Event: X25519 encryption pubkey announced to realm directory.
%%%
%%% Emitter publishes this to `{realm}.identity.public_key_announced`
%%% for the realm server to index. Payload carries the identity MRI
%%% (grantee form for DID-scope licenses) and the 32-byte X25519 pubkey.
%%% @end
-module(identity_public_key_announced_v1).
-behaviour(evoq_event).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([event_type/0]).

-record(identity_public_key_announced_v1, {
    membership_id         :: binary(),
    mri                   :: binary(),
    encryption_public_key :: binary(),
    announced_at          :: integer()
}).

-opaque identity_public_key_announced_v1() :: #identity_public_key_announced_v1{}.
-export_type([identity_public_key_announced_v1/0]).

event_type() -> <<"identity_public_key_announced_v1">>.

new(#{membership_id := MId,
      mri := Mri,
      encryption_public_key := Pub} = Params) ->
    At = maps:get(announced_at, Params, erlang:system_time(millisecond)),
    {ok, new(MId, Mri, Pub, At)}.

-spec new(binary(), binary(), binary(), integer())
      -> identity_public_key_announced_v1().
new(MembershipId, Mri, Pub, At) ->
    #identity_public_key_announced_v1{
        membership_id = MembershipId,
        mri = Mri,
        encryption_public_key = Pub,
        announced_at = At
    }.

to_map(#identity_public_key_announced_v1{
    membership_id = MId,
    mri = Mri,
    encryption_public_key = Pub,
    announced_at = At
}) ->
    #{
        event_type => event_type(),
        membership_id => MId,
        mri => Mri,
        encryption_public_key => Pub,
        announced_at => At
    }.

from_map(#{membership_id := MId,
           mri := Mri,
           encryption_public_key := Pub,
           announced_at := At}) ->
    {ok, new(MId, Mri, Pub, At)};
from_map(_) ->
    {error, invalid_identity_public_key_announced_event}.
