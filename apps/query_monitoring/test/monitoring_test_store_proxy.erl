-module(monitoring_test_store_proxy).
-behaviour(gen_server).
-export([start/1, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-record(state, {db :: reference(), path :: string()}).
start(DbPath) -> gen_server:start({local, query_monitoring_store}, ?MODULE, DbPath, []).
stop() -> gen_server:stop(query_monitoring_store).
init(DbPath) ->
    {ok, Db} = esqlite3:open(DbPath), ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    create_tables(Db), {ok, #state{db = Db, path = DbPath}}.
handle_call(init_schema, _From, #state{db = Db} = S) -> {reply, create_tables(Db), S};
handle_call({execute, Sql, []}, _From, #state{db = Db} = S) -> {reply, esqlite3:exec(Db, Sql), S};
handle_call({execute, Sql, Params}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of {ok, St} -> ok = esqlite3:bind(St, Params), step(St), {reply, ok, S}; E -> {reply, E, S} end;
handle_call({query, Sql, []}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of {ok, St} -> {reply, {ok, ensure_tuples(esqlite3:fetchall(St))}, S}; E -> {reply, E, S} end;
handle_call({query, Sql, Params}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of {ok, St} -> ok = esqlite3:bind(St, Params), {reply, {ok, ensure_tuples(esqlite3:fetchall(St))}, S}; E -> {reply, E, S} end;
handle_call(_, _From, S) -> {reply, {error, unknown_call}, S}.
handle_cast(_, S) -> {noreply, S}. handle_info(_, S) -> {noreply, S}.
terminate(_, #state{db = Db, path = P}) -> esqlite3:close(Db), file:delete(P), ok.
step(St) -> case esqlite3:step(St) of '$done' -> ok; {row,_} -> step(St); ok -> ok end.
ensure_tuples(Rows) -> [ensure_tuple(R) || R <- Rows].
ensure_tuple(T) when is_tuple(T) -> T;
ensure_tuple(L) when is_list(L) -> list_to_tuple(L).
create_tables(Db) ->
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, [
        "CREATE TABLE IF NOT EXISTS monitorings (division_id TEXT PRIMARY KEY, status INTEGER NOT NULL DEFAULT 1, status_label TEXT DEFAULT 'Initiated', started_at INTEGER, started_by TEXT, paused_at INTEGER, pause_reason TEXT, completed_at INTEGER);",
        "CREATE TABLE IF NOT EXISTS health_checks (check_id TEXT PRIMARY KEY, division_id TEXT NOT NULL, check_name TEXT NOT NULL, check_type TEXT, endpoint TEXT, interval_ms INTEGER, registered_at INTEGER NOT NULL, last_status TEXT, last_latency_ms INTEGER, last_checked_at INTEGER);",
        "CREATE TABLE IF NOT EXISTS incidents (incident_id TEXT PRIMARY KEY, division_id TEXT NOT NULL, incident_title TEXT NOT NULL, severity TEXT, description TEXT, raised_at INTEGER NOT NULL);",
        "CREATE INDEX IF NOT EXISTS idx_monitorings_status ON monitorings(status);",
        "CREATE INDEX IF NOT EXISTS idx_health_checks_division ON health_checks(division_id);",
        "CREATE INDEX IF NOT EXISTS idx_incidents_division ON incidents(division_id);",
        "CREATE INDEX IF NOT EXISTS idx_incidents_severity ON incidents(severity);"
    ]), ok.
