-module(maybe_track_rpc_call).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
%% Suppress supertype warnings (returns specific map/binary, spec uses map()/binary())
-dialyzer({nowarn_function, [handle/1, generate_call_id/4]}).

%% @doc Handle track_rpc_call command - tracks an RPC call for reputation scoring.
%%
%% Business rules:
%% - Generate unique call ID
%% - Record call success/failure
%% - Track duration for performance reputation
%% - Create rpc_call_tracked event
-spec handle(track_rpc_call_v1:track_rpc_call_v1()) ->
    {ok, [map()]} | {error, caller_identity_required | callee_identity_required | procedure_required | cannot_track_self_call}.
handle(Command) ->
    #{
        caller_identity := Caller,
        callee_identity := Callee,
        procedure := Procedure,
        call_duration_ms := Duration,
        success := Success,
        error_reason := Error,
        metadata := Metadata,
        timestamp := Timestamp
    } = track_rpc_call_v1:to_map(Command),

    %% Business rules validation
    case validate_track_rpc_call(Caller, Callee, Procedure) of
        ok ->
            %% Generate call ID
            CallId = generate_call_id(Caller, Callee, Procedure, Timestamp),

            %% Create event
            Event = rpc_call_tracked_v1:new(
                CallId,
                Caller,
                Callee,
                Procedure,
                Duration,
                Success,
                Error,
                Metadata,
                Timestamp
            ),

            {ok, [rpc_call_tracked_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-spec validate_track_rpc_call(binary(), binary(), binary()) ->
    ok | {error, caller_identity_required | callee_identity_required | procedure_required | cannot_track_self_call}.
validate_track_rpc_call(Caller, Callee, Procedure) ->
    case {byte_size(Caller), byte_size(Callee), byte_size(Procedure)} of
        {0, _, _} -> {error, caller_identity_required};
        {_, 0, _} -> {error, callee_identity_required};
        {_, _, 0} -> {error, procedure_required};
        {_, _, _} when Caller =:= Callee -> {error, cannot_track_self_call};
        _ -> ok
    end.

-spec generate_call_id(binary(), binary(), binary(), integer()) -> binary().
generate_call_id(Caller, Callee, Procedure, Timestamp) ->
    %% Generate deterministic call ID: call-{timestamp}-{hash}
    HashInput = <<Caller/binary, Callee/binary, Procedure/binary, (integer_to_binary(Timestamp))/binary>>,
    Hash = crypto:hash(sha256, HashInput),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"call-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(track_rpc_call_v1:track_rpc_call_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CalleeIdentity = maps:get(callee_identity, track_rpc_call_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = track_rpc_call,
        aggregate_type = reputation_aggregate,
        aggregate_id = CalleeIdentity,
        payload = maps:merge(track_rpc_call_v1:to_map(Cmd), #{command_type => track_rpc_call}),
        metadata = #{timestamp => Timestamp, aggregate_type => reputation_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_reputation_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
