%%% @doc SQLite storage for capability read models
-module(query_capabilities_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    db :: term()  %% esqlite3 connection (type not in PLT)
}).

%%% Public API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Initialize database schema
init_schema() ->
    gen_server:call(?MODULE, init_schema).

%% @doc Execute SQL statement (no result expected)
execute(Sql) ->
    execute(Sql, []).

execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

%% @doc Query SQL statement (returns rows)
query(Sql) ->
    query(Sql, []).

query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

%%% gen_server callbacks

init([]) ->
    %% Get data directory from application env
    DataDir = application:get_env(query_capabilities, data_dir, "data"),
    DbPath = filename:join(DataDir, "capabilities.db"),

    %% Ensure directory exists
    ok = filelib:ensure_dir(DbPath),

    %% Open SQLite database
    {ok, Db} = esqlite3:open(DbPath),

    {ok, #state{db = Db}}.

handle_call(init_schema, _From, #state{db = Db} = State) ->
    %% Local capabilities - announced by THIS gateway/services
    LocalSchema = "
        CREATE TABLE IF NOT EXISTS capabilities (
            mri TEXT PRIMARY KEY,
            agent_id TEXT NOT NULL,
            tags TEXT NOT NULL,
            description TEXT NOT NULL,
            demo_procedure TEXT,
            metadata TEXT,
            announced_at INTEGER NOT NULL,
            updated_at INTEGER,
            retracted_at INTEGER,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );

        CREATE INDEX IF NOT EXISTS idx_capabilities_agent_id
            ON capabilities(agent_id);

        CREATE INDEX IF NOT EXISTS idx_capabilities_announced_at
            ON capabilities(announced_at DESC);

        CREATE INDEX IF NOT EXISTS idx_capabilities_active
            ON capabilities(mri) WHERE retracted_at IS NULL;
    ",

    %% Remote capabilities - discovered from OTHER agents via mesh
    %% Used for capability discovery queries
    RemoteSchema = "
        CREATE TABLE IF NOT EXISTS remote_capabilities (
            mri TEXT PRIMARY KEY,
            agent_id TEXT NOT NULL,
            tags TEXT NOT NULL,
            description TEXT NOT NULL,
            demo_procedure TEXT,
            metadata TEXT,
            announced_at INTEGER NOT NULL,
            discovered_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            last_seen_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );

        CREATE INDEX IF NOT EXISTS idx_remote_capabilities_agent_id
            ON remote_capabilities(agent_id);

        CREATE INDEX IF NOT EXISTS idx_remote_capabilities_tags
            ON remote_capabilities(tags);

        CREATE INDEX IF NOT EXISTS idx_remote_capabilities_last_seen
            ON remote_capabilities(last_seen_at DESC);
    ",

    ok = esqlite3:exec(Db, LocalSchema),
    ok = esqlite3:exec(Db, RemoteSchema),

    %% Schema migrations: add columns that may not exist yet
    %% SQLite ALTER TABLE ADD COLUMN is idempotent-safe via error handling
    migrate_add_column(Db, "remote_capabilities", "latency_ms", "INTEGER"),
    migrate_add_column(Db, "remote_capabilities", "last_latency_check", "INTEGER"),

    {reply, ok, State};

handle_call({execute, Sql, Params}, _From, #state{db = Db} = State) ->
    %% Use esqlite3:q for parameterized queries (exec/3 doesn't exist)
    %% For execute, we just care about success/failure, not results
    %% Note: esqlite3:q returns [] for INSERT/UPDATE (no rows), not {ok, _}
    case esqlite3:q(Db, Sql, Params) of
        Rows when is_list(Rows) -> {reply, ok, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end;

handle_call({query, Sql, Params}, _From, #state{db = Db} = State) ->
    %% esqlite3:q returns [[col1, col2,...], ...] or {error, Reason}
    %% Wrap in {ok, Rows} for consistency
    case esqlite3:q(Db, Sql, Params) of
        Rows when is_list(Rows) -> {reply, {ok, Rows}, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{db = Db}) ->
    esqlite3:close(Db),
    ok.

%% @private Add a column if it doesn't exist. Silently ignores "duplicate column" errors.
migrate_add_column(Db, Table, Column, Type) ->
    Sql = lists:flatten(io_lib:format(
        "ALTER TABLE ~s ADD COLUMN ~s ~s", [Table, Column, Type])),
    case esqlite3:exec(Db, Sql) of
        ok -> ok;
        {error, _} -> ok  %% Column already exists
    end.
