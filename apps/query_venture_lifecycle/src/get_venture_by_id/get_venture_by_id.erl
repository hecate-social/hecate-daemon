%%% @doc Query: get a venture by its ID.
-module(get_venture_by_id).

-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(VentureId) ->
    Sql = "SELECT venture_id, name, brief, status, status_label, "
          "repos, skills, context_map, initiated_at, initiated_by "
          "FROM ventures WHERE venture_id = ?1",
    case query_venture_lifecycle_store:query(Sql, [VentureId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
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
