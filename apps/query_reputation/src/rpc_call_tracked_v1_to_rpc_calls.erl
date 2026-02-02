-module(rpc_call_tracked_v1_to_rpc_calls).

-export([project/2]).

%% @doc Project rpc_call_tracked_v1 event to rpc_calls table.
-spec project(map(), map()) -> ok | {error, term()}.
project(EventData, _Metadata) ->
    #{
        call_id := CallId,
        caller_identity := Caller,
        callee_identity := Callee,
        procedure := Procedure,
        call_duration_ms := Duration,
        success := Success,
        tracked_at := TrackedAt
    } = EventData,

    ErrorReason = maps:get(error_reason, EventData, null),
    Metadata = maps:get(metadata, EventData, #{}),
    MetadataJson = json:encode(Metadata),

    SuccessInt = case Success of true -> 1; false -> 0 end,

    {ok, Conn} = application:get_env(query_reputation, db_conn),

    SQL = <<"
        INSERT INTO rpc_calls (
            call_id, caller_identity, callee_identity, procedure,
            call_duration_ms, success, error_reason, metadata, tracked_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(call_id) DO UPDATE SET
            call_duration_ms = excluded.call_duration_ms,
            success = excluded.success,
            error_reason = excluded.error_reason,
            tracked_at = excluded.tracked_at
    ">>,

    case esqlite3:q(Conn, SQL, [CallId, Caller, Callee, Procedure, Duration, SuccessInt, ErrorReason, MetadataJson, TrackedAt]) of
        [] -> ok;
        {error, Reason} -> {error, Reason}
    end.
