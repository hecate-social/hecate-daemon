%%% @doc Query: list Torches with optional filters
-module(list_torches).

-export([execute/1]).

%% Bit flag for archived status
-define(ARCHIVED, 32).

%% @doc List torches with optional filters.
%% Supported filters: status, include_archived (default false), limit, offset.
%% By default, archived torches are excluded unless include_archived=true.
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
            {ok, [enrich_status(row_to_map(R)) || R <- Rows]};
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

%% Exclude archived torches by default unless include_archived is true
maybe_exclude_archived(Filters, Clauses, Params, N) ->
    case maps:get(include_archived, Filters, false) of
        true -> {Clauses, Params, N};
        _ ->
            %% Use bitwise AND to check if ARCHIVED flag is NOT set
            Clause = "(status & " ++ integer_to_list(?ARCHIVED) ++ ") = 0",
            {Clauses ++ [Clause], Params, N}
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
row_to_map({TorchId, Name, Brief, Status, Repos, Skills, ContextMap,
            ActiveCartwheelId, InitiatedAt, InitiatedBy}) ->
    row_to_map_impl(TorchId, Name, Brief, Status, Repos, Skills, ContextMap,
                    ActiveCartwheelId, InitiatedAt, InitiatedBy);
row_to_map([TorchId, Name, Brief, Status, Repos, Skills, ContextMap,
            ActiveCartwheelId, InitiatedAt, InitiatedBy]) ->
    row_to_map_impl(TorchId, Name, Brief, Status, Repos, Skills, ContextMap,
                    ActiveCartwheelId, InitiatedAt, InitiatedBy).

row_to_map_impl(TorchId, Name, Brief, Status, Repos, Skills, ContextMap,
                ActiveCartwheelId, InitiatedAt, InitiatedBy) ->
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

enrich_status(#{status := Status} = Row) ->
    Label = evoq_bit_flags:to_string(Status, torch_aggregate:flag_map()),
    Row#{status_label => Label}.

-spec decode_json(binary() | undefined) -> term().
decode_json(undefined) -> undefined;
decode_json(null) -> undefined;
decode_json(Bin) when is_binary(Bin) -> json:decode(Bin);
decode_json(_) -> undefined.
