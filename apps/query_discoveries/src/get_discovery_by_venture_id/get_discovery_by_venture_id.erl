%%% @doc Query: get discovery state for a venture
-module(get_discovery_by_venture_id).
-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(VentureId) ->
    Sql = "SELECT venture_id, status, status_label, started_at, started_by, "
          "paused_at, pause_reason, completed_at "
          "FROM discoveries WHERE venture_id = ?1",
    case query_discoveries_store:query(Sql, [VentureId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({VentureId, Status, StatusLabel, StartedAt, StartedBy,
            PausedAt, PauseReason, CompletedAt}) ->
    #{
        venture_id => VentureId,
        status => Status,
        status_label => StatusLabel,
        started_at => StartedAt,
        started_by => StartedBy,
        paused_at => PausedAt,
        pause_reason => PauseReason,
        completed_at => CompletedAt
    };
row_to_map([VentureId, Status, StatusLabel, StartedAt, StartedBy,
            PausedAt, PauseReason, CompletedAt]) ->
    row_to_map({VentureId, Status, StatusLabel, StartedAt, StartedBy,
                PausedAt, PauseReason, CompletedAt}).
