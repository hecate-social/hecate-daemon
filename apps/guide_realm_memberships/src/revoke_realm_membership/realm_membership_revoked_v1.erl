%%% @doc realm_membership_revoked_v1 event
-module(realm_membership_revoked_v1).

-behaviour(evoq_event).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([event_type/0]).

-record(realm_membership_revoked_v1, {
    membership_id :: binary(),
    reason        :: binary(),
    revoked_at    :: integer()
}).

-opaque realm_membership_revoked_v1() :: #realm_membership_revoked_v1{}.
-export_type([realm_membership_revoked_v1/0]).

-spec new(binary(), binary(), integer()) -> realm_membership_revoked_v1().
event_type() -> <<"realm_membership_revoked_v1">>.

new(#{membership_id := MembershipId, reason := Reason, revoked_at := RevokedAt}) ->
    new(MembershipId, Reason, RevokedAt).

new(MembershipId, Reason, RevokedAt) ->
    #realm_membership_revoked_v1{
        membership_id = MembershipId,
        reason = Reason,
        revoked_at = RevokedAt
    }.

-spec to_map(realm_membership_revoked_v1()) -> map().
to_map(#realm_membership_revoked_v1{
    membership_id = MembershipId,
    reason = Reason,
    revoked_at = RevokedAt
}) ->
    #{
        event_type => <<"realm_membership_revoked_v1">>,
        membership_id => MembershipId,
        reason => Reason,
        revoked_at => RevokedAt
    }.

-spec from_map(map()) -> {ok, realm_membership_revoked_v1()} | {error, term()}.
from_map(#{membership_id := MId, reason := Reason, revoked_at := At}) ->
    {ok, #realm_membership_revoked_v1{
        membership_id = MId,
        reason = Reason,
        revoked_at = At
    }};
from_map(_) ->
    {error, invalid_realm_membership_revoked_event}.
