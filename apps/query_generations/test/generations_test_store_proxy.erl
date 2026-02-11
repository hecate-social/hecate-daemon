-module(generations_test_store_proxy).
-behaviour(gen_server).
-export([start/1, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-record(state, {db :: reference(), path :: string()}).
start(DbPath) -> gen_server:start({local, query_generations_store}, ?MODULE, DbPath, []).
stop() -> gen_server:stop(query_generations_store).
init(DbPath) ->
    {ok, Db} = esqlite3:open(DbPath), ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    create_tables(Db), {ok, #state{db = Db, path = DbPath}}.
handle_call(init_schema, _From, #state{db = Db} = S) -> {reply, create_tables(Db), S};
handle_call({execute, Sql, []}, _From, #state{db = Db} = S) -> {reply, esqlite3:exec(Db, Sql), S};
handle_call({execute, Sql, Params}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of {ok, St} -> ok = esqlite3:bind(St, Params), step(St), {reply, ok, S}; E -> {reply, E, S} end;
handle_call({query, Sql, []}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of {ok, St} -> {reply, {ok, et(esqlite3:fetchall(St))}, S}; E -> {reply, E, S} end;
handle_call({query, Sql, Params}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of {ok, St} -> ok = esqlite3:bind(St, Params), {reply, {ok, et(esqlite3:fetchall(St))}, S}; E -> {reply, E, S} end;
handle_call(_, _From, S) -> {reply, {error, unknown_call}, S}.
handle_cast(_, S) -> {noreply, S}. handle_info(_, S) -> {noreply, S}.
terminate(_, #state{db = Db, path = P}) -> esqlite3:close(Db), file:delete(P), ok.
step(St) -> case esqlite3:step(St) of '$done' -> ok; {row,_} -> step(St); ok -> ok end.
et(Rows) -> [case R of T when is_tuple(T) -> T; L when is_list(L) -> list_to_tuple(L) end || R <- Rows].
create_tables(Db) ->
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, [
        "CREATE TABLE IF NOT EXISTS generations (division_id TEXT PRIMARY KEY, status INTEGER NOT NULL DEFAULT 1, status_label TEXT DEFAULT 'Initiated', started_at INTEGER, started_by TEXT, paused_at INTEGER, pause_reason TEXT, completed_at INTEGER);",
        "CREATE TABLE IF NOT EXISTS generated_modules (module_id TEXT PRIMARY KEY, division_id TEXT NOT NULL, module_name TEXT NOT NULL, module_type TEXT, file_path TEXT, content TEXT, description TEXT, generated_by TEXT, generated_at INTEGER NOT NULL);",
        "CREATE TABLE IF NOT EXISTS generated_tests (test_id TEXT PRIMARY KEY, division_id TEXT NOT NULL, test_name TEXT NOT NULL, test_type TEXT, module_name TEXT, file_path TEXT, content TEXT, description TEXT, generated_by TEXT, generated_at INTEGER NOT NULL);",
        "CREATE INDEX IF NOT EXISTS idx_generations_status ON generations(status);",
        "CREATE INDEX IF NOT EXISTS idx_generated_modules_division ON generated_modules(division_id);",
        "CREATE INDEX IF NOT EXISTS idx_generated_tests_division ON generated_tests(division_id);"
    ]), ok.
