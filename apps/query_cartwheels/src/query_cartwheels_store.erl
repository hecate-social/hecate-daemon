%%% @doc SQLite connection pool for query_cartwheels read models.
-module(query_cartwheels_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference()}).

-define(DB_PATH, "data/query_cartwheels.db").

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    filelib:ensure_dir(?DB_PATH),
    {ok, Db} = esqlite3:open(?DB_PATH),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    %% Create tables on startup
    ok = create_tables(Db),
    {ok, #state{db = Db}}.

%% @doc Initialize database schema
-spec init_schema() -> ok.
init_schema() ->
    gen_server:call(?MODULE, init_schema).

%% @doc Execute SQL statement (no results)
-spec execute(iodata()) -> ok | {error, term()}.
execute(Sql) ->
    gen_server:call(?MODULE, {execute, Sql, []}).

-spec execute(iodata(), [term()]) -> ok | {error, term()}.
execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

%% @doc Query SQL (returns rows)
-spec query(iodata()) -> {ok, [tuple()]} | {error, term()}.
query(Sql) ->
    gen_server:call(?MODULE, {query, Sql, []}).

-spec query(iodata(), [term()]) -> {ok, [tuple()]} | {error, term()}.
query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

handle_call(init_schema, _From, #state{db = Db} = State) ->
    Result = create_tables(Db),
    {reply, Result, State};

handle_call({execute, Sql, Params}, _From, #state{db = Db} = State) ->
    case Params of
        [] ->
            Result = esqlite3:exec(Db, Sql),
            {reply, Result, State};
        _ ->
            case esqlite3:prepare(Db, Sql) of
                {ok, Stmt} ->
                    ok = esqlite3:bind(Stmt, Params),
                    step_until_done(Stmt),
                    {reply, ok, State};
                {error, _} = Err ->
                    {reply, Err, State}
            end
    end;

handle_call({query, Sql, Params}, _From, #state{db = Db} = State) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} ->
            case Params of
                [] -> ok;
                _ -> ok = esqlite3:bind(Stmt, Params)
            end,
            Rows = esqlite3:fetchall(Stmt),
            {reply, {ok, Rows}, State};
        {error, _} = Err ->
            {reply, Err, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{db = Db}) ->
    esqlite3:close(Db).

%% Internal

step_until_done(Stmt) ->
    case esqlite3:step(Stmt) of
        '$done' -> ok;
        {row, _} -> step_until_done(Stmt);
        ok -> ok
    end.

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS cartwheels (
            cartwheel_id TEXT PRIMARY KEY,
            torch_id TEXT,
            context_name TEXT NOT NULL,
            description TEXT,
            current_phase TEXT DEFAULT 'discovery_n_analysis',
            status INTEGER DEFAULT 1,
            status_label TEXT DEFAULT 'New',
            finding_count INTEGER DEFAULT 0,
            term_count INTEGER DEFAULT 0,
            dossier_count INTEGER DEFAULT 0,
            spoke_count INTEGER DEFAULT 0,
            plan_approved INTEGER DEFAULT 0,
            skeleton_created INTEGER DEFAULT 0,
            implemented_spoke_count INTEGER DEFAULT 0,
            build_verified INTEGER DEFAULT 0,
            deployment_count INTEGER DEFAULT 0,
            active_incidents INTEGER DEFAULT 0,
            initiated_at INTEGER,
            phase_started_at INTEGER,
            completed_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_cartwheels_torch ON cartwheels(torch_id);",
        "CREATE INDEX IF NOT EXISTS idx_cartwheels_phase ON cartwheels(current_phase);",
        "CREATE INDEX IF NOT EXISTS idx_cartwheels_status ON cartwheels(status);",

        "CREATE TABLE IF NOT EXISTS findings (
            finding_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            category TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT,
            priority TEXT DEFAULT 'should',
            recorded_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_findings_cartwheel ON findings(cartwheel_id);",
        "CREATE INDEX IF NOT EXISTS idx_findings_category ON findings(category);",

        "CREATE TABLE IF NOT EXISTS terms (
            term_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            term TEXT NOT NULL,
            definition TEXT NOT NULL,
            defined_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_terms_cartwheel ON terms(cartwheel_id);",

        "CREATE TABLE IF NOT EXISTS dossier_designs (
            dossier_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            dossier_name TEXT NOT NULL,
            stream_pattern TEXT DEFAULT 'default',
            description TEXT,
            defined_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_dossier_designs_cartwheel ON dossier_designs(cartwheel_id);",

        "CREATE TABLE IF NOT EXISTS spoke_inventory (
            spoke_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            spoke_name TEXT NOT NULL,
            spoke_type TEXT NOT NULL,
            priority TEXT DEFAULT 'should',
            dossier_id TEXT NOT NULL,
            description TEXT,
            inventoried_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_spoke_inventory_cartwheel ON spoke_inventory(cartwheel_id);",
        "CREATE INDEX IF NOT EXISTS idx_spoke_inventory_dossier ON spoke_inventory(dossier_id);",

        "CREATE TABLE IF NOT EXISTS plans (
            plan_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            title TEXT NOT NULL,
            content_ref TEXT,
            drafted_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_plans_cartwheel ON plans(cartwheel_id);",

        "CREATE TABLE IF NOT EXISTS spoke_implementations (
            implementation_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            spoke_id TEXT NOT NULL,
            implementation_notes TEXT,
            implemented_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_spoke_implementations_cartwheel ON spoke_implementations(cartwheel_id);",
        "CREATE INDEX IF NOT EXISTS idx_spoke_implementations_spoke ON spoke_implementations(spoke_id);",

        "CREATE TABLE IF NOT EXISTS build_verifications (
            build_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            result TEXT DEFAULT 'pass',
            notes TEXT,
            verified_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_build_verifications_cartwheel ON build_verifications(cartwheel_id);",

        "CREATE TABLE IF NOT EXISTS deployments (
            deployment_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            environment TEXT NOT NULL,
            version TEXT NOT NULL,
            notes TEXT,
            deployed_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_deployments_cartwheel ON deployments(cartwheel_id);",

        "CREATE TABLE IF NOT EXISTS incidents (
            incident_id TEXT PRIMARY KEY,
            cartwheel_id TEXT NOT NULL,
            severity TEXT DEFAULT 'medium',
            description TEXT NOT NULL,
            resolution TEXT,
            reported_at INTEGER,
            resolved_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_incidents_cartwheel ON incidents(cartwheel_id);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
