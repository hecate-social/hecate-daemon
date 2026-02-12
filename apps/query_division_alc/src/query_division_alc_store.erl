%%% @doc SQLite store for query_division_alc read models.
%%%
%%% Tables: divisions + 14 domain tables
%%% Absorbs: query_designs_store, query_plans_store, query_generations_store,
%%%          query_tests_store, query_deployments_store, query_monitoring_store,
%%%          query_rescues_store
%%% @end
-module(query_division_alc_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference()}).

-define(DB_PATH, "data/query_division_alc.db").

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
        %% Main division table
        "CREATE TABLE IF NOT EXISTS divisions (
            division_id TEXT PRIMARY KEY,
            venture_id TEXT NOT NULL,
            context_name TEXT,
            overall_status INTEGER NOT NULL DEFAULT 0,
            dna_status INTEGER DEFAULT 0,
            anp_status INTEGER DEFAULT 0,
            tni_status INTEGER DEFAULT 0,
            dno_status INTEGER DEFAULT 0,
            initiated_at INTEGER,
            initiated_by TEXT
        );",
        "CREATE INDEX IF NOT EXISTS idx_divisions_venture ON divisions(venture_id);",
        "CREATE INDEX IF NOT EXISTS idx_divisions_status ON divisions(overall_status);",

        %% DnA domain tables
        "CREATE TABLE IF NOT EXISTS designed_aggregates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            division_id TEXT NOT NULL,
            aggregate_name TEXT NOT NULL,
            description TEXT,
            stream_prefix TEXT,
            fields TEXT,
            designed_at INTEGER NOT NULL,
            UNIQUE(division_id, aggregate_name)
        );",
        "CREATE TABLE IF NOT EXISTS designed_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            division_id TEXT NOT NULL,
            event_name TEXT NOT NULL,
            description TEXT,
            aggregate_name TEXT,
            fields TEXT,
            designed_at INTEGER NOT NULL,
            UNIQUE(division_id, event_name)
        );",

        %% AnP domain tables
        "CREATE TABLE IF NOT EXISTS planned_desks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            division_id TEXT NOT NULL,
            desk_name TEXT NOT NULL,
            description TEXT,
            department TEXT,
            commands TEXT,
            planned_at INTEGER NOT NULL,
            UNIQUE(division_id, desk_name)
        );",
        "CREATE TABLE IF NOT EXISTS planned_dependencies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            division_id TEXT NOT NULL,
            dependency_id TEXT NOT NULL,
            from_desk TEXT,
            to_desk TEXT,
            dep_type TEXT,
            planned_at INTEGER NOT NULL,
            UNIQUE(division_id, dependency_id)
        );",

        %% TnI domain tables
        "CREATE TABLE IF NOT EXISTS generated_modules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            division_id TEXT NOT NULL,
            module_name TEXT NOT NULL,
            module_type TEXT,
            path TEXT,
            generated_at INTEGER NOT NULL,
            UNIQUE(division_id, module_name)
        );",
        "CREATE TABLE IF NOT EXISTS generated_tests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            division_id TEXT NOT NULL,
            test_name TEXT NOT NULL,
            module_name TEXT,
            path TEXT,
            generated_at INTEGER NOT NULL,
            UNIQUE(division_id, test_name)
        );",
        "CREATE TABLE IF NOT EXISTS test_suites (
            suite_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            suite_name TEXT,
            run_at INTEGER NOT NULL
        );",
        "CREATE TABLE IF NOT EXISTS test_results (
            result_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            suite_id TEXT,
            passed INTEGER DEFAULT 0,
            failed INTEGER DEFAULT 0,
            recorded_at INTEGER NOT NULL
        );",

        %% DnO domain tables
        "CREATE TABLE IF NOT EXISTS releases (
            release_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            version TEXT,
            deployed_at INTEGER NOT NULL
        );",
        "CREATE TABLE IF NOT EXISTS rollout_stages (
            stage_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            release_id TEXT,
            stage_name TEXT,
            staged_at INTEGER NOT NULL
        );",
        "CREATE TABLE IF NOT EXISTS health_checks (
            check_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            check_name TEXT,
            check_type TEXT,
            last_status TEXT,
            last_checked_at INTEGER,
            registered_at INTEGER NOT NULL
        );",
        "CREATE TABLE IF NOT EXISTS incidents (
            incident_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            title TEXT,
            severity TEXT,
            raised_at INTEGER NOT NULL
        );",
        "CREATE TABLE IF NOT EXISTS diagnoses (
            diagnosis_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            incident_id TEXT,
            root_cause TEXT,
            diagnosed_at INTEGER NOT NULL
        );",
        "CREATE TABLE IF NOT EXISTS fixes (
            fix_id TEXT PRIMARY KEY,
            division_id TEXT NOT NULL,
            incident_id TEXT,
            description TEXT,
            applied_at INTEGER NOT NULL
        );"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
