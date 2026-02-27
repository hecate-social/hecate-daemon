%%% @doc confirm_realm_membership_v1 command
-module(confirm_realm_membership_v1).

-export([new/5, to_map/1, from_map/1]).

-record(confirm_realm_membership_v1, {
    membership_id  :: binary(),
    realm_id       :: binary(),
    oauth_account  :: binary(),
    oauth_provider :: binary(),
    confirmed_at   :: integer()
}).

-opaque confirm_realm_membership_v1() :: #confirm_realm_membership_v1{}.
-export_type([confirm_realm_membership_v1/0]).

-spec new(binary(), binary(), binary(), binary(), integer()) -> confirm_realm_membership_v1().
new(MembershipId, RealmId, OAuthAccount, OAuthProvider, ConfirmedAt) ->
    #confirm_realm_membership_v1{
        membership_id = MembershipId,
        realm_id = RealmId,
        oauth_account = OAuthAccount,
        oauth_provider = OAuthProvider,
        confirmed_at = ConfirmedAt
    }.

-spec to_map(confirm_realm_membership_v1()) -> map().
to_map(#confirm_realm_membership_v1{
    membership_id = MembershipId,
    realm_id = RealmId,
    oauth_account = OAuthAccount,
    oauth_provider = OAuthProvider,
    confirmed_at = ConfirmedAt
}) ->
    #{
        membership_id => MembershipId,
        realm_id => RealmId,
        oauth_account => OAuthAccount,
        oauth_provider => OAuthProvider,
        confirmed_at => ConfirmedAt
    }.

-spec from_map(map()) -> {ok, confirm_realm_membership_v1()} | {error, term()}.
from_map(#{membership_id := MId, realm_id := RId,
           oauth_account := Acct, oauth_provider := Prov,
           confirmed_at := At}) ->
    {ok, #confirm_realm_membership_v1{
        membership_id = MId,
        realm_id = RId,
        oauth_account = Acct,
        oauth_provider = Prov,
        confirmed_at = At
    }};
from_map(_) ->
    {error, invalid_confirm_realm_membership_command}.
