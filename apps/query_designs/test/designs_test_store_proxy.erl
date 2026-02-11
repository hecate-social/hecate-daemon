%%% @doc Test helper: proxy gen_server that stands in for query_designs_store.
%%% Returns rows as tuples to match esqlite3:q/3 format used by real store.
-module(designs_test_store_proxy).
-behaviour(gen_server).

-export([start/1, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference(), path :: string()}).

start(DbPath) ->
    gen_server:start({local, query_designs_store}, ?MODULE, DbPath, []).

stop() ->
    gen_server:stop(query_designs_store).

init(DbPath) ->
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    create_tables(Db),
    {ok, #state{db = Db, path = DbPath}}.

handle_call(init_schema, _From, #state{db = Db} = State) ->
    Result = create_tables(Db),
    {reply, Result, State};

handle_call({execute, Sql, []}, _From, #state{db = Db} = State) ->
    Result = esqlite3:exec(Db, Sql),
    {reply, Result, State};

handle_call({execute, Sql, Params}, _From, #state{db = Db} = State) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} ->
            ok = esqlite3:bind(Stmt, Params),
            step_until_done(Stmt),
            {reply, ok, State};
        {error, _} = Err ->
            {reply, Err, State}
    end;

handle_call({query, Sql, []}, _From, #state{db = Db} = State) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} ->
            Rows = esqlite3:fetchall(Stmt),
            {reply, {ok, ensure_tuples(Rows)}, State};
        {error, _} = Err ->
            {reply, Err, State}
    end;

handle_call({query, Sql, Params}, _From, #state{db = Db} = State) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} ->
            ok = esqlite3:bind(Stmt, Params),
            Rows = esqlite3:fetchall(Stmt),
            {reply, {ok, ensure_tuples(Rows)}, State};
        {error, _} = Err ->
            {reply, Err, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.

terminate(_Reason, #state{db = Db, path = Path}) ->
    esqlite3:close(Db),
    file:delete(Path),
    ok.

%% Internal

step_until_done(Stmt) ->
    case esqlite3:step(Stmt) of
        '$done' -> ok;
        {row, _} -> step_until_done(Stmt);
        ok -> ok
    end.

%% Ensure rows are tuples to match esqlite3:q/3 format
ensure_tuples(Rows) ->
    [ensure_tuple(R) || R <- Rows].

ensure_tuple(T) when is_tuple(T) -> T;
ensure_tuple(L) when is_list(L) -> list_to_tuple(L).

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS designs ("
        "  division_id TEXT PRIMARY KEY,"
        "  status INTEGER NOT NULL DEFAULT 1,"
        "  status_label TEXT DEFAULT 'Initiated',"
        "  started_at INTEGER,"
        "  started_by TEXT,"
        "  paused_at INTEGER,"
        "  pause_reason TEXT,"
        "  completed_at INTEGER"
        ");",
        "CREATE TABLE IF NOT EXISTS designed_aggregates ("
        "  aggregate_id TEXT PRIMARY KEY,"
        "  division_id TEXT NOT NULL,"
        "  aggregate_name TEXT NOT NULL,"
        "  stream_pattern TEXT,"
        "  status_flags TEXT,"
        "  description TEXT,"
        "  designed_by TEXT,"
        "  designed_at INTEGER NOT NULL"
        ");",
        "CREATE TABLE IF NOT EXISTS designed_events ("
        "  event_id TEXT PRIMARY KEY,"
        "  division_id TEXT NOT NULL,"
        "  event_name TEXT NOT NULL,"
        "  aggregate_name TEXT NOT NULL,"
        "  payload_fields TEXT,"
        "  description TEXT,"
        "  designed_by TEXT,"
        "  designed_at INTEGER NOT NULL"
        ");",
        "CREATE INDEX IF NOT EXISTS idx_designs_status ON designs(status);",
        "CREATE INDEX IF NOT EXISTS idx_designed_aggregates_division ON designed_aggregates(division_id);",
        "CREATE INDEX IF NOT EXISTS idx_designed_events_division ON designed_events(division_id);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
