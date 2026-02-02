-module(handle_get_reputation).

-export([handle/1]).

%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle get_reputation query - retrieve reputation score and stats for an agent.
-spec handle(get_reputation_v1:get_reputation_v1()) -> {ok, map()} | {error, term()}.
handle(Query) ->
    #{agent_identity := Identity} = get_reputation_v1:to_map(Query),

    {ok, Conn} = application:get_env(query_reputation, db_conn),

    SQL = <<"
        SELECT
            agent_identity, total_calls, successful_calls, failed_calls,
            total_duration_ms, disputes_flagged, disputes_upheld, reputation_score
        FROM agent_reputation
        WHERE agent_identity = ?
    ">>,

    case esqlite3:q(Conn, SQL, [Identity]) of
        [[Identity, Total, Success, Failed, Duration, Flagged, Upheld, Score]] ->
            {ok, #{
                agent_identity => Identity,
                total_calls => Total,
                successful_calls => Success,
                failed_calls => Failed,
                average_duration_ms => case Total of 0 -> 0; _ -> Duration div Total end,
                disputes_flagged => Flagged,
                disputes_upheld => Upheld,
                reputation_score => Score
            }};
        [] ->
            %% No reputation data - return default
            {ok, #{
                agent_identity => Identity,
                total_calls => 0,
                successful_calls => 0,
                failed_calls => 0,
                average_duration_ms => 0,
                disputes_flagged => 0,
                disputes_upheld => 0,
                reputation_score => 0.0
            }};
        {error, Reason} ->
            {error, Reason}
    end.
