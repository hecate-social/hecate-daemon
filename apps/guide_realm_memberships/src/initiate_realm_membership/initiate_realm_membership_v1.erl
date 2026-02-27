%%% @doc initiate_realm_membership_v1 command
-module(initiate_realm_membership_v1).

-export([new/3, to_map/1, from_map/1]).

-record(initiate_realm_membership_v1, {
    membership_id :: binary(),
    realm_url     :: binary(),
    initiated_at  :: integer()
}).

-opaque initiate_realm_membership_v1() :: #initiate_realm_membership_v1{}.
-export_type([initiate_realm_membership_v1/0]).

-spec new(binary(), binary(), integer()) -> initiate_realm_membership_v1().
new(MembershipId, RealmUrl, InitiatedAt) ->
    #initiate_realm_membership_v1{
        membership_id = MembershipId,
        realm_url = RealmUrl,
        initiated_at = InitiatedAt
    }.

-spec to_map(initiate_realm_membership_v1()) -> map().
to_map(#initiate_realm_membership_v1{
    membership_id = MembershipId,
    realm_url = RealmUrl,
    initiated_at = InitiatedAt
}) ->
    #{
        membership_id => MembershipId,
        realm_url => RealmUrl,
        initiated_at => InitiatedAt
    }.

-spec from_map(map()) -> {ok, initiate_realm_membership_v1()} | {error, term()}.
from_map(#{membership_id := MId, realm_url := RUrl, initiated_at := At}) ->
    {ok, #initiate_realm_membership_v1{
        membership_id = MId,
        realm_url = RUrl,
        initiated_at = At
    }};
from_map(_) ->
    {error, invalid_initiate_realm_membership_command}.
