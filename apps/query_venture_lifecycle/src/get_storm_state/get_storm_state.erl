%%% @doc Query: get the current Big Picture Event Storming state for a venture.
%%% Assembles session, stickies, clusters, and fact arrows into one map.
-module(get_storm_state).

-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, term()}.
get(VentureId) ->
    %% Get current storm session
    SessionSql = "SELECT venture_id, storm_number, phase, started_at, shelved_at, completed_at "
                 "FROM storm_sessions WHERE venture_id = ?1 "
                 "ORDER BY storm_number DESC LIMIT 1",
    case query_venture_lifecycle_store:query(SessionSql, [VentureId]) of
        {ok, []} ->
            {ok, #{phase => <<"ready">>, storm_number => 0,
                   stickies => [], clusters => [], arrows => []}};
        {ok, [SessionRow]} ->
            StormNumber = get_storm_number(SessionRow),
            Phase = get_phase(SessionRow),
            %% Get stickies for this storm
            StickyRows = query_stickies(VentureId, StormNumber),
            %% Get clusters for this storm
            ClusterRows = query_clusters(VentureId, StormNumber),
            %% Get fact arrows for this storm
            ArrowRows = query_arrows(VentureId, StormNumber),
            {ok, #{
                phase => Phase,
                storm_number => StormNumber,
                started_at => get_started_at(SessionRow),
                shelved_at => get_shelved_at(SessionRow),
                stickies => format_stickies(StickyRows),
                clusters => format_clusters(ClusterRows),
                arrows => format_arrows(ArrowRows)
            }};
        {error, Reason} ->
            {error, Reason}
    end.

query_stickies(VentureId, StormNumber) ->
    Sql = "SELECT sticky_id, text, author, weight, stack_id, cluster_id, created_at "
          "FROM event_stickies WHERE venture_id = ?1 AND storm_number = ?2",
    case query_venture_lifecycle_store:query(Sql, [VentureId, StormNumber]) of
        {ok, Rows} -> Rows;
        _ -> []
    end.

query_clusters(VentureId, StormNumber) ->
    Sql = "SELECT cluster_id, name, color, status, created_at "
          "FROM event_clusters WHERE venture_id = ?1 AND storm_number = ?2",
    case query_venture_lifecycle_store:query(Sql, [VentureId, StormNumber]) of
        {ok, Rows} -> Rows;
        _ -> []
    end.

query_arrows(VentureId, StormNumber) ->
    Sql = "SELECT arrow_id, from_cluster, to_cluster, fact_name, created_at "
          "FROM fact_arrows WHERE venture_id = ?1 AND storm_number = ?2",
    case query_venture_lifecycle_store:query(Sql, [VentureId, StormNumber]) of
        {ok, Rows} -> Rows;
        _ -> []
    end.

%% IMPORTANT: esqlite3 fetchall returns list-of-lists, NOT tuples!
get_storm_number([_V, SN | _]) -> SN;
get_storm_number(_) -> 0.

get_phase([_V, _SN, P | _]) -> P;
get_phase(_) -> <<"storm">>.

get_started_at([_V, _SN, _P, SA | _]) -> SA;
get_started_at(_) -> undefined.

get_shelved_at([_V, _SN, _P, _SA, ShA | _]) -> ShA;
get_shelved_at(_) -> undefined.

format_stickies(Rows) ->
    [format_sticky(R) || R <- Rows].

format_sticky([StickyId, Text, Author, Weight, StackId, ClusterId, CreatedAt]) ->
    #{sticky_id => StickyId, text => Text, author => Author,
      weight => Weight, stack_id => StackId, cluster_id => ClusterId,
      created_at => CreatedAt};
format_sticky(_) -> #{}.

format_clusters(Rows) ->
    [format_cluster(R) || R <- Rows].

format_cluster([ClusterId, Name, Color, Status, CreatedAt]) ->
    #{cluster_id => ClusterId, name => Name, color => Color,
      status => Status, created_at => CreatedAt};
format_cluster(_) -> #{}.

format_arrows(Rows) ->
    [format_arrow(R) || R <- Rows].

format_arrow([ArrowId, FromCluster, ToCluster, FactName, CreatedAt]) ->
    #{arrow_id => ArrowId, from_cluster => FromCluster,
      to_cluster => ToCluster, fact_name => FactName,
      created_at => CreatedAt};
format_arrow(_) -> #{}.
