%%% @doc Handler for revoke_realm_membership command
-module(maybe_revoke_realm_membership).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    MembershipId = maps:get(membership_id, Payload, <<>>),
    Reason = maps:get(reason, Payload, <<"manual">>),
    RevokedAt = maps:get(revoked_at, Payload, erlang:system_time(millisecond)),
    Cmd = revoke_realm_membership_v1:new(MembershipId, Reason, RevokedAt),
    handle(Cmd).

-spec handle(revoke_realm_membership_v1:revoke_realm_membership_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{membership_id := MembershipId} = revoke_realm_membership_v1:to_map(Command),
    case byte_size(MembershipId) of
        0 -> {error, membership_id_required};
        _ ->
            EventMap = revoke_realm_membership_v1:to_map(Command),
            {ok, [EventMap#{event_type => <<"realm_membership_revoked_v1">>}]}
    end.

-spec dispatch(revoke_realm_membership_v1:revoke_realm_membership_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{membership_id := MembershipId} = revoke_realm_membership_v1:to_map(Cmd),
    StreamId = membership_aggregate:stream_id(MembershipId),
    CmdMap = revoke_realm_membership_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = revoke_realm_membership,
        aggregate_type = membership_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => revoke_realm_membership},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => realm_memberships_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
