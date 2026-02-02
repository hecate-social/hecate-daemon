%%% @doc Handler for record_endorsement_revoked command
-module(maybe_record_endorsement_revoked).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{
        endorser_identity := Endorser,
        my_capability_mri := CapMri,
        my_identity := MyIdentity,
        revoked_at := RevokedAt
    } = record_endorsement_revoked_v1:to_map(Command),

    RecordedAt = erlang:system_time(millisecond),
    Event = endorsement_revocation_received_v1:new(Endorser, CapMri, MyIdentity, RevokedAt, RecordedAt),
    {ok, [endorsement_revocation_received_v1:to_map(Event)]}.

-spec dispatch(record_endorsement_revoked_v1:record_endorsement_revoked_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = record_endorsement_revoked_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = record_endorsement_revoked_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = record_endorsement_revoked,
        aggregate_type = my_endorsements_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => record_endorsement_revoked},
        metadata = #{timestamp => Timestamp, source => mesh_fact},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_social_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AggId, Ts) ->
    Hash = crypto:hash(sha256, <<AggId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-record_endorsement_revoked-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
