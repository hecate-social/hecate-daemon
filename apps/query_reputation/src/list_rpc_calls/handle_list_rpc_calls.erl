-module(handle_list_rpc_calls).

-export([handle/1]).

%% Suppress supertype warning (error type from esqlite3 is integer, spec uses term())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle list_rpc_calls query - list RPC calls for an agent with optional filtering.
-spec handle(list_rpc_calls_v1:list_rpc_calls_v1()) -> {ok, [map()]} | {error, term()}.
handle(Query) ->
    #{
        agent_identity := Identity,
        limit := Limit,
        success_filter := Filter
    } = list_rpc_calls_v1:to_map(Query),

    {ok, Conn} = application:get_env(query_reputation, db_conn),

    {SQL, Params} = build_query(Identity, Filter, Limit),

    case esqlite3:q(Conn, SQL, Params) of
        Rows when is_list(Rows) ->
            Results = [row_to_rpc_call(R) || R <- Rows],
            {ok, Results};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

build_query(Identity, undefined, Limit) ->
    {<<"
        SELECT call_id, caller_identity, callee_identity, procedure,
               call_duration_ms, success, error_reason, tracked_at
        FROM rpc_calls
        WHERE caller_identity = ? OR callee_identity = ?
        ORDER BY tracked_at DESC
        LIMIT ?
    ">>, [Identity, Identity, Limit]};
build_query(Identity, Success, Limit) ->
    SuccessInt = case Success of true -> 1; false -> 0 end,
    {<<"
        SELECT call_id, caller_identity, callee_identity, procedure,
               call_duration_ms, success, error_reason, tracked_at
        FROM rpc_calls
        WHERE (caller_identity = ? OR callee_identity = ?) AND success = ?
        ORDER BY tracked_at DESC
        LIMIT ?
    ">>, [Identity, Identity, SuccessInt, Limit]}.

row_to_rpc_call([CallId, Caller, Callee, Procedure, Duration, SuccessInt, ErrorReason, TrackedAt]) ->
    Success = case SuccessInt of 1 -> true; _ -> false end,
    #{
        call_id => CallId,
        caller_identity => Caller,
        callee_identity => Callee,
        procedure => Procedure,
        call_duration_ms => Duration,
        success => Success,
        error_reason => ErrorReason,
        tracked_at => TrackedAt
    }.
