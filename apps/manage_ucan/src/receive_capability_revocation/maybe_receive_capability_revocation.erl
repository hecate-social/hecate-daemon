%%% @doc Handler for receive_capability_revocation command
%%% SECURITY-CRITICAL: Must immediately invalidate the revoked capability
-module(maybe_receive_capability_revocation).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{
        capability_id := CapId,
        my_identity := MyIdentity,
        revoker := Revoker,
        revoked_at := RevokedAt
    } = receive_capability_revocation_v1:to_map(Command),

    %% TODO: Additional validation could go here
    %% - Verify revoker has authority to revoke (is the issuer or in chain)
    %% - Check capability exists in received_capabilities
    RecordedAt = erlang:system_time(millisecond),
    Event = capability_revocation_received_v1:new(CapId, MyIdentity, Revoker, RevokedAt, RecordedAt),
    {ok, [capability_revocation_received_v1:to_map(Event)]}.

-spec dispatch(receive_capability_revocation_v1:receive_capability_revocation_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = receive_capability_revocation_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = receive_capability_revocation_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = receive_capability_revocation,
        aggregate_type = received_capabilities_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => receive_capability_revocation},
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
    <<"cmd-receive_capability_revocation-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
