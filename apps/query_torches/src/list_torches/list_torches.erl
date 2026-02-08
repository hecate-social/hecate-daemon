%%% @doc Query: list Torches with optional filters
-module(list_torches).

-export([execute/1]).

%% @doc List torches with optional filters.
%% Supported filters: status, limit, offset.
-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(Filters) ->
    {WhereClauses, Params} = build_where(Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Where = case WhereClauses of
        [] -> "";
        _ -> " WHERE " ++ string:join(WhereClauses, " AND ")
    end,

    ParamCount = length(Params),
    Sql = "SELECT torch_id, name, brief, status, repos, skills, context_map, "
          "active_cartwheel_id, initiated_at, initiated_by "
          "FROM torches" ++ Where ++
          " ORDER BY initiated_at DESC"
          " LIMIT ?" ++ integer_to_list(ParamCount + 1) ++
          " OFFSET ?" ++ integer_to_list(ParamCount + 2),

    AllParams = Params ++ [Limit, Offset],
    case query_torches_store:query(Sql, AllParams) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

build_where(Filters) ->
    build_where(Filters, [], [], 1).

build_where(Filters, Clauses, Params, N) ->
    {C1, P1, N1} = maybe_add_status(Filters, Clauses, Params, N),
    {C2, P2, _N2} = maybe_add_name(Filters, C1, P1, N1),
    {C2, P2}.

maybe_add_status(Filters, Clauses, Params, N) ->
    case maps:get(status, Filters, undefined) of
        undefined -> {Clauses, Params, N};
        Status ->
            Clause = "status = ?" ++ integer_to_list(N),
            {Clauses ++ [Clause], Params ++ [Status], N + 1}
    end.

maybe_add_name(Filters, Clauses, Params, N) ->
    case maps:get(name, Filters, undefined) of
        undefined -> {Clauses, Params, N};
        Name ->
            Clause = "name = ?" ++ integer_to_list(N),
            {Clauses ++ [Clause], Params ++ [Name], N + 1}
    end.

row_to_map({TorchId, Name, Brief, Status, Repos, Skills, ContextMap,
            ActiveCartwheelId, InitiatedAt, InitiatedBy}) ->
    #{
        torch_id => TorchId,
        name => Name,
        brief => Brief,
        status => Status,
        repos => decode_json(Repos),
        skills => decode_json(Skills),
        context_map => decode_json(ContextMap),
        active_cartwheel_id => ActiveCartwheelId,
        initiated_at => InitiatedAt,
        initiated_by => InitiatedBy
    }.

-spec decode_json(binary() | undefined) -> term().
decode_json(undefined) -> undefined;
decode_json(null) -> undefined;
decode_json(Bin) when is_binary(Bin) -> json:decode(Bin);
decode_json(_) -> undefined.
