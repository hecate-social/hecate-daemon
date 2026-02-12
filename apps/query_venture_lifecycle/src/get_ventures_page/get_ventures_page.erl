%%% @doc Query: list ventures with pagination.
-module(get_ventures_page).

-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 20),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT venture_id, name, brief, status, status_label, "
          "repos, skills, context_map, initiated_at, initiated_by "
          "FROM ventures ORDER BY initiated_at DESC "
          "LIMIT ?1 OFFSET ?2",
    case query_venture_lifecycle_store:query(Sql, [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({VentureId, Name, Brief, Status, StatusLabel,
            Repos, Skills, ContextMap, InitiatedAt, InitiatedBy}) ->
    #{
        venture_id => VentureId,
        name => Name,
        brief => Brief,
        status => Status,
        status_label => StatusLabel,
        repos => decode_json(Repos),
        skills => decode_json(Skills),
        context_map => decode_json(ContextMap),
        initiated_at => InitiatedAt,
        initiated_by => InitiatedBy
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).

decode_json(null) -> null;
decode_json(undefined) -> null;
decode_json(Val) when is_binary(Val) -> json:decode(Val);
decode_json(Val) -> Val.
