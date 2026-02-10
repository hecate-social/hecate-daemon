%%% @doc Query: list unapplied remote learnings
-module(get_remote_learnings_page).

-export([execute/0, execute/1]).

-spec execute() -> {ok, [map()]} | {error, term()}.
execute() ->
    execute(#{}).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(Filters) ->
    Limit = maps:get(limit, Filters, 50),
    {Where, Params} = build_where(Filters),

    ParamCount = length(Params),
    Sql = "SELECT id, source_agent, category, domain, title, "
          "learning_data, discovered_at, applied "
          "FROM remote_learnings"
          ++ Where ++
          " ORDER BY discovered_at DESC"
          " LIMIT ?" ++ integer_to_list(ParamCount + 1),

    AllParams = Params ++ [Limit],
    case query_mentors_store:query(Sql, AllParams) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

build_where(Filters) ->
    Clauses0 = case maps:get(applied, Filters, false) of
        true -> [];
        false -> ["applied = 0"]
    end,
    {C1, P1, _N1} = maybe_add(domain, Filters, Clauses0, [], 1),
    case C1 of
        [] -> {"", P1};
        _ -> {" WHERE " ++ string:join(C1, " AND "), P1}
    end.

maybe_add(Key, Filters, Clauses, Params, N) ->
    case maps:get(Key, Filters, undefined) of
        undefined -> {Clauses, Params, N};
        Value ->
            Clause = atom_to_list(Key) ++ " = ?" ++ integer_to_list(N),
            {Clauses ++ [Clause], Params ++ [Value], N + 1}
    end.

row_to_map({Id, SourceAgent, Category, Domain, Title,
            LearningData, DiscoveredAt, Applied}) ->
    #{
        id => Id,
        source_agent => SourceAgent,
        category => Category,
        domain => Domain,
        title => Title,
        learning_data => LearningData,
        discovered_at => DiscoveredAt,
        applied => Applied
    }.
