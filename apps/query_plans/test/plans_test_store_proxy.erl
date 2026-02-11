%%% @doc Test helper: proxy gen_server for query_plans_store.
-module(plans_test_store_proxy).
-behaviour(gen_server).
-export([start/1, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-record(state, {db :: reference(), path :: string()}).

start(DbPath) -> gen_server:start({local, query_plans_store}, ?MODULE, DbPath, []).
stop() -> gen_server:stop(query_plans_store).

init(DbPath) ->
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    create_tables(Db),
    {ok, #state{db = Db, path = DbPath}}.

handle_call(init_schema, _From, #state{db = Db} = S) -> {reply, create_tables(Db), S};
handle_call({execute, Sql, []}, _From, #state{db = Db} = S) -> {reply, esqlite3:exec(Db, Sql), S};
handle_call({execute, Sql, Params}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} -> ok = esqlite3:bind(Stmt, Params), step_until_done(Stmt), {reply, ok, S};
        {error, _} = E -> {reply, E, S}
    end;
handle_call({query, Sql, []}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} -> {reply, {ok, ensure_tuples(esqlite3:fetchall(Stmt))}, S};
        {error, _} = E -> {reply, E, S}
    end;
handle_call({query, Sql, Params}, _From, #state{db = Db} = S) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} -> ok = esqlite3:bind(Stmt, Params), {reply, {ok, ensure_tuples(esqlite3:fetchall(Stmt))}, S};
        {error, _} = E -> {reply, E, S}
    end;
handle_call(_, _From, S) -> {reply, {error, unknown_call}, S}.
handle_cast(_, S) -> {noreply, S}.
handle_info(_, S) -> {noreply, S}.
terminate(_, #state{db = Db, path = P}) -> esqlite3:close(Db), file:delete(P), ok.

step_until_done(Stmt) -> case esqlite3:step(Stmt) of '$done' -> ok; {row,_} -> step_until_done(Stmt); ok -> ok end.
ensure_tuples(Rows) -> [case R of T when is_tuple(T) -> T; L when is_list(L) -> list_to_tuple(L) end || R <- Rows].

create_tables(Db) ->
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, [
        "CREATE TABLE IF NOT EXISTS plans (division_id TEXT PRIMARY KEY, status INTEGER NOT NULL DEFAULT 1, status_label TEXT DEFAULT 'Initiated', started_at INTEGER, started_by TEXT, paused_at INTEGER, pause_reason TEXT, completed_at INTEGER);",
        "CREATE TABLE IF NOT EXISTS planned_desks (desk_id TEXT PRIMARY KEY, division_id TEXT NOT NULL, desk_name TEXT NOT NULL, department TEXT, aggregate_name TEXT, description TEXT, priority INTEGER DEFAULT 0, planned_by TEXT, planned_at INTEGER NOT NULL);",
        "CREATE TABLE IF NOT EXISTS planned_dependencies (dependency_id TEXT PRIMARY KEY, division_id TEXT NOT NULL, from_desk TEXT NOT NULL, to_desk TEXT NOT NULL, dependency_type TEXT, description TEXT, planned_by TEXT, planned_at INTEGER NOT NULL);",
        "CREATE INDEX IF NOT EXISTS idx_plans_status ON plans(status);",
        "CREATE INDEX IF NOT EXISTS idx_planned_desks_division ON planned_desks(division_id);",
        "CREATE INDEX IF NOT EXISTS idx_planned_dependencies_division ON planned_dependencies(division_id);"
    ]), ok.
