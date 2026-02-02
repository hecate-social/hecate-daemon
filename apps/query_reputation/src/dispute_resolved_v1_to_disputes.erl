-module(dispute_resolved_v1_to_disputes).

-export([project/2]).

%% @doc Project dispute_resolved_v1 event to disputes table.
-spec project(map(), map()) -> ok | {error, term()}.
project(EventData, _Metadata) ->
    #{
        dispute_id := DisputeId,
        resolver_identity := Resolver,
        resolution := Resolution,
        resolved_at := ResolvedAt
    } = EventData,

    Notes = maps:get(notes, EventData, <<>>),

    {ok, Conn} = application:get_env(query_reputation, db_conn),

    SQL = <<"
        UPDATE disputes
        SET resolution = ?, resolver_identity = ?, notes = ?, resolved_at = ?
        WHERE dispute_id = ?
    ">>,

    case esqlite3:q(Conn, SQL, [Resolution, Resolver, Notes, ResolvedAt, DisputeId]) of
        [] when Resolution =:= <<"upheld">> ->
            %% Increment disputes_upheld in reputation
            increment_disputes_upheld(DisputeId, Conn);
        [] ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

increment_disputes_upheld(DisputeId, Conn) ->
    %% Get call_id from dispute, then callee from call
    GetCallSQL = <<"
        SELECT rpc_calls.callee_identity
        FROM disputes
        JOIN rpc_calls ON disputes.call_id = rpc_calls.call_id
        WHERE disputes.dispute_id = ?
    ">>,

    case esqlite3:q(Conn, GetCallSQL, [DisputeId]) of
        [[Callee]] ->
            UpdateSQL = <<"
                UPDATE agent_reputation
                SET disputes_upheld = disputes_upheld + 1
                WHERE agent_identity = ?
            ">>,
            _ = esqlite3:q(Conn, UpdateSQL, [Callee]),
            ok;
        _ ->
            ok
    end.
