%%% @doc Query: List all capabilities (with optional filters)
-module(list_capabilities).

-export([execute/0, execute/1]).

%% Suppress supertype warnings (returns specific maps, spec uses map())
-dialyzer({nowarn_function, [execute/0, execute/1]}).

%% @doc List all capabilities
-spec execute() -> {ok, [map()]} | {error, term()}.
execute() ->
    execute(#{}).

%% @doc List capabilities with filters
%% Supported filters:
%%   - agent_id: Filter by agent identity
%%   - tag: Filter by tag (any match)
%%   - limit: Max results (default: 100)
%%   - offset: Skip N results (default: 0)
-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(Filters) ->
    {Sql, Params} = build_query(Filters),

    case query_capabilities_store:query(Sql, Params) of
        {ok, Rows} ->
            Results = lists:map(fun parse_row/1, Rows),
            {ok, Results};

        {error, Reason} ->
            {error, Reason}
    end.

%%% Private functions

build_query(Filters) ->
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),

    %% Base query - excludes retracted capabilities by default
    BaseSql = "
        SELECT mri, agent_id, tags, description, demo_procedure, metadata, announced_at
        FROM capabilities
        WHERE retracted_at IS NULL
    ",

    %% Add filters
    {WhereClauses, Params0} = build_where_clauses(Filters),
    Sql = BaseSql ++ WhereClauses ++ "
        ORDER BY announced_at DESC
        LIMIT ? OFFSET ?
    ",
    Params = Params0 ++ [Limit, Offset],

    {Sql, Params}.

build_where_clauses(Filters) ->
    Clauses = [],
    Params = [],

    %% Filter by agent_id
    {Clauses1, Params1} = case maps:get(agent_id, Filters, undefined) of
        undefined -> {Clauses, Params};
        AgentID -> {Clauses ++ [" AND agent_id = ?"], Params ++ [AgentID]}
    end,

    %% Filter by tag (JSON array contains)
    {Clauses2, Params2} = case maps:get(tag, Filters, undefined) of
        undefined -> {Clauses1, Params1};
        Tag ->
            %% SQLite JSON functions: json_each to expand array
            Clause = " AND EXISTS (
                SELECT 1 FROM json_each(tags) WHERE value = ?
            )",
            {Clauses1 ++ [Clause], Params1 ++ [Tag]}
    end,

    {lists:flatten(Clauses2), Params2}.

parse_row([MRI, AgentID, TagsJson, Desc, DemoProc, MetadataJson, AnnouncedAt]) ->
    Tags = json:decode(TagsJson),
    Metadata = json:decode(MetadataJson),

    #{
        mri => MRI,
        agent_id => AgentID,
        tags => Tags,
        description => Desc,
        demo_procedure => DemoProc,
        metadata => Metadata,
        announced_at => AnnouncedAt
    }.
