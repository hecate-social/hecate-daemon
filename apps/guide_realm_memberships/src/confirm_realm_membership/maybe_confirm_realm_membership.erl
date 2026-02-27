%%% @doc Handler for confirm_realm_membership command
-module(maybe_confirm_realm_membership).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    MembershipId = maps:get(membership_id, Payload, <<>>),
    RealmId = maps:get(realm_id, Payload, <<>>),
    OAuthAccount = maps:get(oauth_account, Payload, <<>>),
    OAuthProvider = maps:get(oauth_provider, Payload, <<>>),
    ConfirmedAt = maps:get(confirmed_at, Payload, erlang:system_time(millisecond)),
    Cmd = confirm_realm_membership_v1:new(MembershipId, RealmId, OAuthAccount, OAuthProvider, ConfirmedAt),
    handle(Cmd).

-spec handle(confirm_realm_membership_v1:confirm_realm_membership_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{membership_id := MembershipId, oauth_account := OAuthAccount} =
        confirm_realm_membership_v1:to_map(Command),
    case {byte_size(MembershipId), byte_size(OAuthAccount)} of
        {0, _} -> {error, membership_id_required};
        {_, 0} -> {error, oauth_account_required};
        _ ->
            EventMap = confirm_realm_membership_v1:to_map(Command),
            {ok, [EventMap#{event_type => <<"realm_membership_confirmed_v1">>}]}
    end.

-spec dispatch(confirm_realm_membership_v1:confirm_realm_membership_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{membership_id := MembershipId} = confirm_realm_membership_v1:to_map(Cmd),
    StreamId = membership_aggregate:stream_id(MembershipId),
    CmdMap = confirm_realm_membership_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = confirm_realm_membership,
        aggregate_type = membership_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => confirm_realm_membership},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => realm_memberships_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
