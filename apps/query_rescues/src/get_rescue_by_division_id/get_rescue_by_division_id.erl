%%% @doc Query: get rescue state for a division.
-module(get_rescue_by_division_id).

-include_lib("rescue_division/include/rescue_status.hrl").

-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(DivisionId) ->
    Sql = "SELECT division_id, incident_id, status, status_label, started_at, started_by, "
          "paused_at, pause_reason, completed_at "
          "FROM rescues WHERE division_id = ?1",
    case query_rescues_store:query(Sql, [DivisionId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({DivisionId, IncidentId, Status, StatusLabel, StartedAt, StartedBy,
            PausedAt, PauseReason, CompletedAt}) ->
    #{
        division_id => DivisionId,
        incident_id => IncidentId,
        status => Status,
        status_label => StatusLabel,
        started_at => StartedAt,
        started_by => StartedBy,
        paused_at => PausedAt,
        pause_reason => PauseReason,
        completed_at => CompletedAt
    };
row_to_map([DivisionId, IncidentId, Status, StatusLabel, StartedAt, StartedBy,
            PausedAt, PauseReason, CompletedAt]) ->
    row_to_map({DivisionId, IncidentId, Status, StatusLabel, StartedAt, StartedBy,
                PausedAt, PauseReason, CompletedAt}).
