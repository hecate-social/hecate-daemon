%%% @doc Query: get a venture by ID
-module(get_venture_by_id).

-export([execute/1]).

%% @doc Get a venture by its ID.
-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(VentureId) ->
    Sql = "SELECT venture_id, name, brief, status, status_label, repos, skills, context_map, "
          "initiated_at, initiated_by "
          "FROM ventures WHERE venture_id = ?1",
    case query_ventures_store:query(Sql, [VentureId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map({VentureId, Name, Brief, Status, StatusLabel, Repos, Skills, ContextMap,
            InitiatedAt, InitiatedBy}) ->
    row_to_map_impl(VentureId, Name, Brief, Status, StatusLabel, Repos, Skills, ContextMap,
                    InitiatedAt, InitiatedBy);
row_to_map([VentureId, Name, Brief, Status, StatusLabel, Repos, Skills, ContextMap,
            InitiatedAt, InitiatedBy]) ->
    row_to_map_impl(VentureId, Name, Brief, Status, StatusLabel, Repos, Skills, ContextMap,
                    InitiatedAt, InitiatedBy).

row_to_map_impl(VentureId, Name, Brief, Status, StatusLabel, Repos, Skills, ContextMap,
                InitiatedAt, InitiatedBy) ->
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
    }.

-spec decode_json(binary() | undefined) -> term().
decode_json(undefined) -> undefined;
decode_json(null) -> undefined;
decode_json(Bin) when is_binary(Bin) -> json:decode(Bin);
decode_json(_) -> undefined.
