%%% @doc Query: list Ventures with optional filters
-module(get_ventures_page).

-include_lib("setup_venture/include/venture_status.hrl").

-export([execute/1]).

%% @doc List ventures with optional filters.
%% Supported filters: status, include_archived (default false), limit, offset.
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
    Sql = "SELECT venture_id, name, brief, status, status_label, repos, skills, context_map, "
          "initiated_at, initiated_by "
          "FROM ventures" ++ Where ++
          " ORDER BY initiated_at DESC"
          " LIMIT ?" ++ integer_to_list(ParamCount + 1) ++
          " OFFSET ?" ++ integer_to_list(ParamCount + 2),

    AllParams = Params ++ [Limit, Offset],
    case query_ventures_store:query(Sql, AllParams) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

build_where(Filters) ->
    build_where(Filters, [], [], 1).

build_where(Filters, Clauses, Params, N) ->
    {C0, P0, N0} = maybe_exclude_archived(Filters, Clauses, Params, N),
    {C1, P1, N1} = maybe_add_status(Filters, C0, P0, N0),
    {C2, P2, _N2} = maybe_add_name(Filters, C1, P1, N1),
    {C2, P2}.

maybe_exclude_archived(Filters, Clauses, Params, N) ->
    case maps:get(include_archived, Filters, false) of
        true -> {Clauses, Params, N};
        _ ->
            Clause = "(status & ?" ++ integer_to_list(N) ++ ") = 0",
            {Clauses ++ [Clause], Params ++ [?VENTURE_ARCHIVED], N + 1}
    end.

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

%% Handle both tuple and list formats from esqlite3
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
