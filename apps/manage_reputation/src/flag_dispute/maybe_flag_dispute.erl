-module(maybe_flag_dispute).

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warnings (returns specific map/binary, spec uses map()/binary())
-dialyzer({nowarn_function, [handle/1, generate_dispute_id/3]}).

%% @doc Handle flag_dispute command - flags an RPC call as disputed.
%%
%% Business rules:
%% - Generate unique dispute ID
%% - Reason is required
%% - Evidence is optional but recommended
-spec handle(flag_dispute_v1:flag_dispute_v1()) ->
    {ok, [map()]} | {error, call_id_required | flagger_identity_required | reason_required}.
handle(Command) ->
    #{
        call_id := CallId,
        flagger_identity := Flagger,
        reason := Reason,
        evidence := Evidence,
        timestamp := Timestamp
    } = flag_dispute_v1:to_map(Command),

    case validate_flag_dispute(CallId, Flagger, Reason) of
        ok ->
            DisputeId = generate_dispute_id(CallId, Flagger, Timestamp),

            Event = dispute_flagged_v1:new(
                DisputeId,
                CallId,
                Flagger,
                Reason,
                Evidence,
                Timestamp
            ),

            {ok, [dispute_flagged_v1:to_map(Event)]};
        {error, ErrorReason} ->
            {error, ErrorReason}
    end.

%% Internal functions

-spec validate_flag_dispute(binary(), binary(), binary()) ->
    ok | {error, call_id_required | flagger_identity_required | reason_required}.
validate_flag_dispute(CallId, Flagger, Reason) ->
    case {byte_size(CallId), byte_size(Flagger), byte_size(Reason)} of
        {0, _, _} -> {error, call_id_required};
        {_, 0, _} -> {error, flagger_identity_required};
        {_, _, 0} -> {error, reason_required};
        _ -> ok
    end.

-spec generate_dispute_id(binary(), binary(), integer()) -> binary().
generate_dispute_id(CallId, Flagger, Timestamp) ->
    HashInput = <<CallId/binary, Flagger/binary, (integer_to_binary(Timestamp))/binary>>,
    Hash = crypto:hash(sha256, HashInput),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"dispute-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(flag_dispute_v1:flag_dispute_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CallId = maps:get(call_id, flag_dispute_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(CallId, Timestamp),
        command_type = flag_dispute,
        aggregate_type = reputation_aggregate,
        aggregate_id = CallId,
        payload = maps:merge(flag_dispute_v1:to_map(Cmd), #{command_type => flag_dispute}),
        metadata = #{timestamp => Timestamp},
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
    <<"cmd-flag_dispute-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
