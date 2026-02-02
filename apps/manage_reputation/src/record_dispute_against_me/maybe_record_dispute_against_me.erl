%%% @doc Handler for record_dispute_against_me command
-module(maybe_record_dispute_against_me).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{
        dispute_id := DisputeId,
        flagger_identity := Flagger,
        my_identity := MyIdentity,
        call_id := CallId,
        reason := Reason,
        flagged_at := FlaggedAt
    } = record_dispute_against_me_v1:to_map(Command),

    %% Validate: flagger can't be me
    case Flagger =/= MyIdentity of
        true ->
            RecordedAt = erlang:system_time(millisecond),
            Event = dispute_against_me_recorded_v1:new(
                DisputeId, Flagger, MyIdentity, CallId, Reason, FlaggedAt, RecordedAt
            ),
            {ok, [dispute_against_me_recorded_v1:to_map(Event)]};
        false ->
            {error, cannot_record_self_dispute}
    end.

-spec dispatch(record_dispute_against_me_v1:record_dispute_against_me_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = record_dispute_against_me_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = record_dispute_against_me_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = record_dispute_against_me,
        aggregate_type = disputes_against_me_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => record_dispute_against_me},
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
    <<"cmd-record_dispute_against_me-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
