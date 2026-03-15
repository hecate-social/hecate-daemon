%%% @doc realm_membership_confirmed_v1 event
-module(realm_membership_confirmed_v1).

-behaviour(evoq_event).

-export([new/1, new/5, to_map/1, from_map/1]).
-export([event_type/0]).

-record(realm_membership_confirmed_v1, {
    membership_id  :: binary(),
    realm_id       :: binary(),
    oauth_account  :: binary(),
    oauth_provider :: binary(),
    confirmed_at   :: integer()
}).

-opaque realm_membership_confirmed_v1() :: #realm_membership_confirmed_v1{}.
-export_type([realm_membership_confirmed_v1/0]).

-spec new(binary(), binary(), binary(), binary(), integer()) -> realm_membership_confirmed_v1().
event_type() -> realm_membership_confirmed_v1.

new(#{membership_id := MembershipId, realm_id := RealmId,
     oauth_account := OAuthAccount, oauth_provider := OAuthProvider,
     confirmed_at := ConfirmedAt}) ->
    new(MembershipId, RealmId, OAuthAccount, OAuthProvider, ConfirmedAt).

new(MembershipId, RealmId, OAuthAccount, OAuthProvider, ConfirmedAt) ->
    #realm_membership_confirmed_v1{
        membership_id = MembershipId,
        realm_id = RealmId,
        oauth_account = OAuthAccount,
        oauth_provider = OAuthProvider,
        confirmed_at = ConfirmedAt
    }.

-spec to_map(realm_membership_confirmed_v1()) -> map().
to_map(#realm_membership_confirmed_v1{
    membership_id = MembershipId,
    realm_id = RealmId,
    oauth_account = OAuthAccount,
    oauth_provider = OAuthProvider,
    confirmed_at = ConfirmedAt
}) ->
    #{
        event_type => <<"realm_membership_confirmed_v1">>,
        membership_id => MembershipId,
        realm_id => RealmId,
        oauth_account => OAuthAccount,
        oauth_provider => OAuthProvider,
        confirmed_at => ConfirmedAt
    }.

-spec from_map(map()) -> {ok, realm_membership_confirmed_v1()} | {error, term()}.
from_map(#{membership_id := MId, realm_id := RId,
           oauth_account := Acct, oauth_provider := Prov,
           confirmed_at := At}) ->
    {ok, #realm_membership_confirmed_v1{
        membership_id = MId,
        realm_id = RId,
        oauth_account = Acct,
        oauth_provider = Prov,
        confirmed_at = At
    }};
from_map(_) ->
    {error, invalid_realm_membership_confirmed_event}.
