-module(rpc_call_tracked_v1).

-export([new/9, to_map/1, from_map/1]).

-record(rpc_call_tracked_v1, {
    call_id :: binary(),
    caller_identity :: binary(),
    callee_identity :: binary(),
    procedure :: binary(),
    call_duration_ms :: non_neg_integer(),
    success :: boolean(),
    error_reason :: binary() | undefined,
    metadata :: map(),
    tracked_at :: integer()
}).

-opaque rpc_call_tracked_v1() :: #rpc_call_tracked_v1{}.
-export_type([rpc_call_tracked_v1/0]).

%% @doc Create a new rpc_call_tracked event.
-spec new(binary(), binary(), binary(), binary(), non_neg_integer(), boolean(), binary() | undefined, map(), integer()) -> rpc_call_tracked_v1().
new(CallId, CallerIdentity, CalleeIdentity, Procedure, DurationMs, Success, ErrorReason, Metadata, TrackedAt) ->
    #rpc_call_tracked_v1{
        call_id = CallId,
        caller_identity = CallerIdentity,
        callee_identity = CalleeIdentity,
        procedure = Procedure,
        call_duration_ms = DurationMs,
        success = Success,
        error_reason = ErrorReason,
        metadata = Metadata,
        tracked_at = TrackedAt
    }.

%% @doc Convert event to map for storage.
-spec to_map(rpc_call_tracked_v1()) -> map().
to_map(#rpc_call_tracked_v1{
    call_id = CallId,
    caller_identity = Caller,
    callee_identity = Callee,
    procedure = Procedure,
    call_duration_ms = Duration,
    success = Success,
    error_reason = Error,
    metadata = Metadata,
    tracked_at = TrackedAt
}) ->
    #{
        event_type => <<"rpc_call_tracked_v1">>,
        call_id => CallId,
        caller_identity => Caller,
        callee_identity => Callee,
        procedure => Procedure,
        call_duration_ms => Duration,
        success => Success,
        error_reason => Error,
        metadata => Metadata,
        tracked_at => TrackedAt
    }.

%% @doc Deserialize event from map (extracted from evoq_event.data).
-spec from_map(map()) -> {ok, rpc_call_tracked_v1()} | {error, term()}.
from_map(#{
    call_id := CallId,
    caller_identity := Caller,
    callee_identity := Callee,
    procedure := Procedure,
    call_duration_ms := Duration,
    success := Success,
    tracked_at := TrackedAt
} = Map) ->
    Error = maps:get(error_reason, Map, undefined),
    Metadata = maps:get(metadata, Map, #{}),

    {ok, #rpc_call_tracked_v1{
        call_id = CallId,
        caller_identity = Caller,
        callee_identity = Callee,
        procedure = Procedure,
        call_duration_ms = Duration,
        success = Success,
        error_reason = Error,
        metadata = Metadata,
        tracked_at = TrackedAt
    }};
from_map(_) ->
    {error, invalid_rpc_call_tracked_event}.
