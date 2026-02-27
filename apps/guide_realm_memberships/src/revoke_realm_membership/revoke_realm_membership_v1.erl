%%% @doc revoke_realm_membership_v1 command
-module(revoke_realm_membership_v1).

-export([new/3, to_map/1, from_map/1]).

-record(revoke_realm_membership_v1, {
    membership_id :: binary(),
    reason        :: binary(),
    revoked_at    :: integer()
}).

-opaque revoke_realm_membership_v1() :: #revoke_realm_membership_v1{}.
-export_type([revoke_realm_membership_v1/0]).

-spec new(binary(), binary(), integer()) -> revoke_realm_membership_v1().
new(MembershipId, Reason, RevokedAt) ->
    #revoke_realm_membership_v1{
        membership_id = MembershipId,
        reason = Reason,
        revoked_at = RevokedAt
    }.

-spec to_map(revoke_realm_membership_v1()) -> map().
to_map(#revoke_realm_membership_v1{
    membership_id = MembershipId,
    reason = Reason,
    revoked_at = RevokedAt
}) ->
    #{
        membership_id => MembershipId,
        reason => Reason,
        revoked_at => RevokedAt
    }.

-spec from_map(map()) -> {ok, revoke_realm_membership_v1()} | {error, term()}.
from_map(#{membership_id := MId, reason := Reason, revoked_at := At}) ->
    {ok, #revoke_realm_membership_v1{
        membership_id = MId,
        reason = Reason,
        revoked_at = At
    }};
from_map(_) ->
    {error, invalid_revoke_realm_membership_command}.
