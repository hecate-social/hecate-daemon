-module(dispute_flagged_v1_to_disputes).

-export([project/2]).

%% @doc Project dispute_flagged_v1 event to disputes table.
-spec project(map(), map()) -> ok | {error, term()}.
project(EventData, _Metadata) ->
    #{
        dispute_id := DisputeId,
        call_id := CallId,
        flagger_identity := Flagger,
        reason := Reason,
        flagged_at := FlaggedAt
    } = EventData,

    Evidence = maps:get(evidence, EventData, #{}),
    EvidenceJson = json:encode(Evidence),

    {ok, Conn} = application:get_env(query_reputation, db_conn),

    SQL = <<"
        INSERT INTO disputes (
            dispute_id, call_id, flagger_identity, reason, evidence, flagged_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(dispute_id) DO NOTHING
    ">>,

    case esqlite3:q(Conn, SQL, [DisputeId, CallId, Flagger, Reason, EvidenceJson, FlaggedAt]) of
        [] ->
            %% Increment disputes_flagged in reputation
            increment_disputes_flagged(CallId, Conn);
        {error, Reason2} ->
            {error, Reason2}
    end.

%% Internal functions

increment_disputes_flagged(CallId, Conn) ->
    %% Get callee from RPC call
    GetCalleeSQL = <<"SELECT callee_identity FROM rpc_calls WHERE call_id = ?">>,

    case esqlite3:q(Conn, GetCalleeSQL, [CallId]) of
        [[Callee]] ->
            UpdateSQL = <<"
                UPDATE agent_reputation
                SET disputes_flagged = disputes_flagged + 1
                WHERE agent_identity = ?
            ">>,
            _ = esqlite3:q(Conn, UpdateSQL, [Callee]),
            ok;
        _ ->
            ok
    end.
