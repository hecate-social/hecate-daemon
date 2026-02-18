%%% @doc SQLite connection pool for query_mentorships read models.
-module(query_mentorships_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    DbPath = shared_paths:sqlite_path("query_mentorships.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
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
        "CREATE TABLE IF NOT EXISTS learnings (
            id TEXT PRIMARY KEY,
            submitter_id TEXT NOT NULL,
            category TEXT NOT NULL,
            domain TEXT NOT NULL,
            tags TEXT,
            title TEXT NOT NULL,
            description TEXT,
            bad_example TEXT,
            good_example TEXT,
            context TEXT,
            severity TEXT DEFAULT 'suggestion',
            confidence REAL DEFAULT 0.5,
            source TEXT DEFAULT 'discovered',
            status INTEGER DEFAULT 1,
            validator_id TEXT,
            endorsement_count INTEGER DEFAULT 0,
            dispute_count INTEGER DEFAULT 0,
            submitted_at INTEGER,
            validated_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_learnings_category ON learnings(category);",
        "CREATE INDEX IF NOT EXISTS idx_learnings_domain ON learnings(domain);",
        "CREATE INDEX IF NOT EXISTS idx_learnings_status ON learnings(status);",

        "CREATE TABLE IF NOT EXISTS mentor_subscriptions (
            subscriber_id TEXT NOT NULL,
            mentor_id TEXT NOT NULL,
            status INTEGER DEFAULT 1,
            subscribed_at INTEGER,
            PRIMARY KEY (subscriber_id, mentor_id)
        );",

        "CREATE TABLE IF NOT EXISTS mentor_profiles (
            agent_id TEXT PRIMARY KEY,
            domains TEXT,
            status INTEGER DEFAULT 1,
            declared_at INTEGER
        );",
        "CREATE INDEX IF NOT EXISTS idx_mentor_profiles_status ON mentor_profiles(status);",

        "CREATE TABLE IF NOT EXISTS remote_learnings (
            id TEXT PRIMARY KEY,
            source_agent TEXT NOT NULL,
            category TEXT,
            domain TEXT,
            title TEXT,
            learning_data TEXT,
            discovered_at INTEGER,
            applied INTEGER DEFAULT 0
        );",
        "CREATE INDEX IF NOT EXISTS idx_remote_learnings_domain ON remote_learnings(domain);",

        "CREATE TABLE IF NOT EXISTS remote_mentors (
            agent_id TEXT PRIMARY KEY,
            domains TEXT,
            discovered_at INTEGER,
            last_seen_at INTEGER
        );"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
