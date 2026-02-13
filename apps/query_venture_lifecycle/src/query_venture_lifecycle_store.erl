%%% @doc SQLite store for query_venture_lifecycle read models.
%%%
%%% Tables: ventures, discovered_divisions, event_stickies,
%%%          event_clusters, fact_arrows, storm_sessions
%%% @end
-module(query_venture_lifecycle_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference()}).

-define(DB_PATH, "data/query_venture_lifecycle.db").

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    filelib:ensure_dir(?DB_PATH),
    {ok, Db} = esqlite3:open(?DB_PATH),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    ok = create_tables(Db),
    {ok, #state{db = Db}}.

-spec init_schema() -> ok.
init_schema() ->
    gen_server:call(?MODULE, init_schema).

-spec execute(iodata()) -> ok | {error, term()}.
execute(Sql) ->
    gen_server:call(?MODULE, {execute, Sql, []}).

-spec execute(iodata(), [term()]) -> ok | {error, term()}.
execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

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
        "CREATE TABLE IF NOT EXISTS ventures (
            venture_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            brief TEXT,
            status INTEGER NOT NULL DEFAULT 0,
            status_label TEXT DEFAULT 'New',
            repos TEXT,
            skills TEXT,
            context_map TEXT,
            initiated_at INTEGER,
            initiated_by TEXT
        );",
        "CREATE INDEX IF NOT EXISTS idx_ventures_status ON ventures(status);",
        "CREATE INDEX IF NOT EXISTS idx_ventures_name ON ventures(name);",

        "CREATE TABLE IF NOT EXISTS discovered_divisions (
            division_id TEXT PRIMARY KEY,
            venture_id TEXT NOT NULL,
            context_name TEXT NOT NULL,
            description TEXT,
            identified_by TEXT,
            discovered_at INTEGER NOT NULL
        );",
        "CREATE INDEX IF NOT EXISTS idx_discovered_divisions_venture
            ON discovered_divisions(venture_id);",

        "CREATE TABLE IF NOT EXISTS event_stickies (
            sticky_id TEXT PRIMARY KEY,
            venture_id TEXT NOT NULL,
            storm_number INTEGER NOT NULL,
            text TEXT NOT NULL,
            author TEXT DEFAULT 'user',
            weight INTEGER DEFAULT 1,
            stack_id TEXT,
            cluster_id TEXT,
            created_at INTEGER NOT NULL
        );",

        "CREATE TABLE IF NOT EXISTS event_clusters (
            cluster_id TEXT PRIMARY KEY,
            venture_id TEXT NOT NULL,
            storm_number INTEGER NOT NULL,
            name TEXT,
            color TEXT NOT NULL,
            status TEXT DEFAULT 'active',
            created_at INTEGER NOT NULL
        );",

        "CREATE TABLE IF NOT EXISTS fact_arrows (
            arrow_id TEXT PRIMARY KEY,
            venture_id TEXT NOT NULL,
            storm_number INTEGER NOT NULL,
            from_cluster TEXT NOT NULL,
            to_cluster TEXT NOT NULL,
            fact_name TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );",

        "CREATE TABLE IF NOT EXISTS storm_sessions (
            venture_id TEXT NOT NULL,
            storm_number INTEGER NOT NULL,
            phase TEXT DEFAULT 'storm',
            started_at INTEGER NOT NULL,
            shelved_at INTEGER,
            completed_at INTEGER,
            PRIMARY KEY (venture_id, storm_number)
        );",

        "CREATE INDEX IF NOT EXISTS idx_stickies_venture
            ON event_stickies(venture_id, storm_number);",
        "CREATE INDEX IF NOT EXISTS idx_clusters_venture
            ON event_clusters(venture_id, storm_number);",
        "CREATE INDEX IF NOT EXISTS idx_arrows_venture
            ON fact_arrows(venture_id, storm_number);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
