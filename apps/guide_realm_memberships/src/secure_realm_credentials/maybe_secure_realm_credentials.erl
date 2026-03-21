%%% @doc Handler for secure_realm_credentials command.
%%%
%%% Validates the command and emits realm_credentials_secured_v1 event.
-module(maybe_secure_realm_credentials).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    MembershipId = maps:get(membership_id, Payload, <<>>),
    EncCreds = maps:get(encrypted_credentials, Payload, <<>>),
    Cmd = secure_realm_credentials_v1:new(MembershipId, EncCreds),
    handle(Cmd).

-spec handle(secure_realm_credentials_v1:secure_realm_credentials_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{membership_id := MembershipId, encrypted_credentials := EncCreds} =
        secure_realm_credentials_v1:to_map(Command),
    case {byte_size(MembershipId), byte_size(EncCreds)} of
        {0, _} -> {error, membership_id_required};
        {_, 0} -> {error, credentials_required};
        _ ->
            Now = erlang:system_time(millisecond),
            Event = realm_credentials_secured_v1:new(MembershipId, EncCreds, Now),
            {ok, [realm_credentials_secured_v1:to_map(Event)]}
    end.

-spec dispatch(secure_realm_credentials_v1:secure_realm_credentials_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{membership_id := MembershipId} = secure_realm_credentials_v1:to_map(Cmd),
    StreamId = membership_aggregate:stream_id(MembershipId),
    CmdMap = secure_realm_credentials_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = secure_realm_credentials,
        aggregate_type = membership_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => secure_realm_credentials},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => realm_memberships_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
