%%% @doc Test helper: proxy gen_server for query_discoveries_store.
-module(discoveries_test_store_proxy).
-behaviour(gen_server).

-export([start/1, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference(), path :: string()}).

start(DbPath) ->
    gen_server:start({local, query_discoveries_store}, ?MODULE, DbPath, []).

stop() ->
    gen_server:stop(query_discoveries_store).

init(DbPath) ->
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    create_tables(Db),
    {ok, #state{db = Db, path = DbPath}}.

handle_call(init_schema, _From, #state{db = Db} = State) ->
    {reply, create_tables(Db), State};

handle_call({execute, Sql, []}, _From, #state{db = Db} = State) ->
    {reply, esqlite3:exec(Db, Sql), State};

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

step_until_done(Stmt) ->
    case esqlite3:step(Stmt) of
        '$done' -> ok;
        {row, _} -> step_until_done(Stmt);
        ok -> ok
    end.

ensure_tuples(Rows) -> [ensure_tuple(R) || R <- Rows].
ensure_tuple(T) when is_tuple(T) -> T;
ensure_tuple(L) when is_list(L) -> list_to_tuple(L).

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS discoveries ("
        "  venture_id TEXT PRIMARY KEY,"
        "  status INTEGER NOT NULL DEFAULT 1,"
        "  status_label TEXT DEFAULT 'Initiated',"
        "  started_at INTEGER,"
        "  started_by TEXT,"
        "  paused_at INTEGER,"
        "  pause_reason TEXT,"
        "  completed_at INTEGER"
        ");",
        "CREATE TABLE IF NOT EXISTS discovered_divisions ("
        "  division_id TEXT PRIMARY KEY,"
        "  venture_id TEXT NOT NULL,"
        "  context_name TEXT NOT NULL,"
        "  description TEXT,"
        "  identified_by TEXT,"
        "  discovered_at INTEGER NOT NULL"
        ");",
        "CREATE INDEX IF NOT EXISTS idx_discoveries_status ON discoveries(status);",
        "CREATE INDEX IF NOT EXISTS idx_discovered_divisions_venture ON discovered_divisions(venture_id);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
