-module(rpc_call_tracked_v1_to_reputation).

-export([project/2]).

%% @doc Project rpc_call_tracked_v1 event to agent_reputation table (aggregated view).
-spec project(map(), map()) -> ok | {error, term()}.
project(EventData, _Metadata) ->
    #{
        callee_identity := Callee,
        call_duration_ms := Duration,
        success := Success,
        tracked_at := TrackedAt
    } = EventData,

    SuccessIncr = case Success of true -> 1; false -> 0 end,
    FailIncr = case Success of false -> 1; true -> 0 end,

    {ok, Conn} = application:get_env(query_reputation, db_conn),

    SQL = <<"
        INSERT INTO agent_reputation (
            agent_identity, total_calls, successful_calls, failed_calls,
            total_duration_ms, last_updated
        ) VALUES (?, 1, ?, ?, ?, ?)
        ON CONFLICT(agent_identity) DO UPDATE SET
            total_calls = total_calls + 1,
            successful_calls = successful_calls + excluded.successful_calls,
            failed_calls = failed_calls + excluded.failed_calls,
            total_duration_ms = total_duration_ms + excluded.total_duration_ms,
            last_updated = excluded.last_updated
    ">>,

    case esqlite3:q(Conn, SQL, [Callee, SuccessIncr, FailIncr, Duration, TrackedAt]) of
        [] ->
            %% Recalculate reputation score
            update_reputation_score(Callee, Conn);
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

update_reputation_score(AgentIdentity, Conn) ->
    GetSQL = <<"
        SELECT total_calls, successful_calls, disputes_upheld
        FROM agent_reputation
        WHERE agent_identity = ?
    ">>,

    case esqlite3:q(Conn, GetSQL, [AgentIdentity]) of
        [[Total, Success, Upheld]] when is_integer(Total), Total > 0 ->
            SuccessRate = Success / Total,
            DisputePenalty = case Upheld of undefined -> 0; N when is_number(N) -> N * 0.1; _ -> 0 end,
            Score = max(0.0, SuccessRate - DisputePenalty),

            UpdateSQL = <<"UPDATE agent_reputation SET reputation_score = ? WHERE agent_identity = ?">>,
            _ = esqlite3:q(Conn, UpdateSQL, [Score, AgentIdentity]),
            ok;
        _ ->
            ok
    end.
