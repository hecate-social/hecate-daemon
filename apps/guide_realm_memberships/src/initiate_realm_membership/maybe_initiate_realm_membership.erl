%%% @doc Handler for initiate_realm_membership command
-module(maybe_initiate_realm_membership).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    MembershipId = maps:get(membership_id, Payload, <<>>),
    RealmUrl = maps:get(realm_url, Payload, <<>>),
    InitiatedAt = maps:get(initiated_at, Payload, erlang:system_time(millisecond)),
    Cmd = initiate_realm_membership_v1:new(MembershipId, RealmUrl, InitiatedAt),
    handle(Cmd).

-spec handle(initiate_realm_membership_v1:initiate_realm_membership_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{membership_id := MembershipId, realm_url := RealmUrl} =
        initiate_realm_membership_v1:to_map(Command),
    case {byte_size(MembershipId), byte_size(RealmUrl)} of
        {0, _} -> {error, membership_id_required};
        {_, 0} -> {error, realm_url_required};
        _ ->
            Event = initiate_realm_membership_v1:to_map(Command),
            {ok, [Event#{event_type => <<"realm_membership_initiated_v1">>}]}
    end.

-spec dispatch(initiate_realm_membership_v1:initiate_realm_membership_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{membership_id := MembershipId} = initiate_realm_membership_v1:to_map(Cmd),
    StreamId = membership_aggregate:stream_id(MembershipId),
    CmdMap = initiate_realm_membership_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = initiate_realm_membership,
        aggregate_type = membership_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => initiate_realm_membership},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => realm_memberships_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
