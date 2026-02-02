%%% @doc Handler for record_dispute_resolution command
-module(maybe_record_dispute_resolution).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{
        dispute_id := DisputeId,
        my_identity := MyIdentity,
        resolution := Resolution,
        resolver_identity := Resolver,
        notes := Notes,
        resolved_at := ResolvedAt
    } = record_dispute_resolution_v1:to_map(Command),

    RecordedAt = erlang:system_time(millisecond),
    Event = dispute_resolution_recorded_v1:new(
        DisputeId, MyIdentity, Resolution, Resolver, Notes, ResolvedAt, RecordedAt
    ),
    {ok, [dispute_resolution_recorded_v1:to_map(Event)]}.

-spec dispatch(record_dispute_resolution_v1:record_dispute_resolution_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = record_dispute_resolution_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = record_dispute_resolution_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = record_dispute_resolution,
        aggregate_type = disputes_against_me_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => record_dispute_resolution},
        metadata = #{timestamp => Timestamp, source => mesh_fact},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_reputation_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AggId, Ts) ->
    Hash = crypto:hash(sha256, <<AggId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-record_dispute_resolution-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
