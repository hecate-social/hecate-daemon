%%% @doc Handler for receive_capability command
%%% SECURITY-CRITICAL: Validates and records incoming capability grants
-module(maybe_receive_capability).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{
        capability_id := CapId,
        issuer := Issuer,
        my_identity := MyIdentity,
        resource := Resource,
        actions := Actions,
        expires_at := ExpiresAt,
        granted_at := GrantedAt,
        token_cid := TokenCid
    } = receive_capability_v1:to_map(Command),

    %% Validate: issuer can't be me (can't grant to myself from mesh)
    case Issuer =/= MyIdentity of
        true ->
            %% TODO: Additional UCAN validation could go here
            %% - Verify token signature
            %% - Check issuer has authority to grant
            %% - Validate resource format
            RecordedAt = erlang:system_time(millisecond),
            Event = capability_received_v1:new(
                CapId, Issuer, MyIdentity, Resource, Actions,
                ExpiresAt, GrantedAt, TokenCid, RecordedAt
            ),
            {ok, [capability_received_v1:to_map(Event)]};
        false ->
            {error, cannot_receive_self_granted_capability}
    end.

-spec dispatch(receive_capability_v1:receive_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = receive_capability_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = receive_capability_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = receive_capability,
        aggregate_type = received_capabilities_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => receive_capability},
        metadata = #{timestamp => Timestamp, source => mesh_fact, security_critical => true},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_ucan_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AggId, Ts) ->
    Hash = crypto:hash(sha256, <<AggId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-receive_capability-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
