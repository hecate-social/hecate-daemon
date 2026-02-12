%%% @doc Query: get venture status including division count.
-module(get_venture_status).

-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(VentureId) ->
    Sql = "SELECT status, status_label FROM ventures WHERE venture_id = ?1",
    case query_venture_lifecycle_store:query(Sql, [VentureId]) of
        {ok, [[Status, StatusLabel]]} ->
            DivisionCount = count_divisions(VentureId),
            {ok, #{
                venture_id => VentureId,
                status => Status,
                status_label => StatusLabel,
                discovered_divisions_count => DivisionCount
            }};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

count_divisions(VentureId) ->
    Sql = "SELECT COUNT(*) FROM discovered_divisions WHERE venture_id = ?1",
    case query_venture_lifecycle_store:query(Sql, [VentureId]) of
        {ok, [[Count]]} -> Count;
        _ -> 0
    end.
