-module(track_rpc_call_v1).

-export([new/8, to_map/1, from_map/1]).

-record(track_rpc_call_v1, {
    caller_identity :: binary(),
    callee_identity :: binary(),
    procedure :: binary(),
    call_duration_ms :: non_neg_integer(),
    success :: boolean(),
    error_reason :: binary() | undefined,
    metadata :: map(),
    timestamp :: integer()
}).

-opaque track_rpc_call_v1() :: #track_rpc_call_v1{}.
-export_type([track_rpc_call_v1/0]).

%% @doc Create a new track_rpc_call command.
-spec new(binary(), binary(), binary(), non_neg_integer(), boolean(), binary() | undefined, map(), integer()) -> track_rpc_call_v1().
new(CallerIdentity, CalleeIdentity, Procedure, DurationMs, Success, ErrorReason, Metadata, Timestamp) ->
    #track_rpc_call_v1{
        caller_identity = CallerIdentity,
        callee_identity = CalleeIdentity,
        procedure = Procedure,
        call_duration_ms = DurationMs,
        success = Success,
        error_reason = ErrorReason,
        metadata = Metadata,
        timestamp = Timestamp
    }.

%% @doc Convert command to map for serialization.
-spec to_map(track_rpc_call_v1()) -> map().
to_map(#track_rpc_call_v1{
    caller_identity = Caller,
    callee_identity = Callee,
    procedure = Procedure,
    call_duration_ms = Duration,
    success = Success,
    error_reason = Error,
    metadata = Metadata,
    timestamp = Timestamp
}) ->
    #{
        caller_identity => Caller,
        callee_identity => Callee,
        procedure => Procedure,
        call_duration_ms => Duration,
        success => Success,
        error_reason => Error,
        metadata => Metadata,
        timestamp => Timestamp
    }.

%% @doc Deserialize command from map.
-spec from_map(map()) -> {ok, track_rpc_call_v1()} | {error, term()}.
from_map(#{
    caller_identity := Caller,
    callee_identity := Callee,
    procedure := Procedure,
    call_duration_ms := Duration,
    success := Success
} = Map) ->
    Error = maps:get(error_reason, Map, undefined),
    Metadata = maps:get(metadata, Map, #{}),
    Timestamp = maps:get(timestamp, Map, erlang:system_time(millisecond)),

    {ok, #track_rpc_call_v1{
        caller_identity = Caller,
        callee_identity = Callee,
        procedure = Procedure,
        call_duration_ms = Duration,
        success = Success,
        error_reason = Error,
        metadata = Metadata,
        timestamp = Timestamp
    }};
from_map(_) ->
    {error, invalid_track_rpc_call_command}.
