%%% @doc Query: get monitoring state for a division.
-module(get_monitoring_by_division_id).

-include_lib("monitor_division/include/monitoring_status.hrl").

-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(DivisionId) ->
    Sql = "SELECT division_id, status, status_label, started_at, started_by, "
          "paused_at, pause_reason, completed_at "
          "FROM monitorings WHERE division_id = ?1",
    case query_monitoring_store:query(Sql, [DivisionId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({DivisionId, Status, StatusLabel, StartedAt, StartedBy,
            PausedAt, PauseReason, CompletedAt}) ->
    #{
        division_id => DivisionId,
        status => Status,
        status_label => StatusLabel,
        started_at => StartedAt,
        started_by => StartedBy,
        paused_at => PausedAt,
        pause_reason => PauseReason,
        completed_at => CompletedAt
    };
row_to_map([DivisionId, Status, StatusLabel, StartedAt, StartedBy,
            PausedAt, PauseReason, CompletedAt]) ->
    row_to_map({DivisionId, Status, StatusLabel, StartedAt, StartedBy,
                PausedAt, PauseReason, CompletedAt}).
