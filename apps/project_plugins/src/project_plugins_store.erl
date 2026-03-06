%%% @doc SQLite store for node read models.
%%%
%%% Tables: plugins
%%% Populated by event projections (plugin_installed_v1, etc.).
%%% @end
-module(project_plugins_store).
-behaviour(gen_server).

-export([start_link/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: esqlite3:esqlite3()}).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    DbPath = shared_paths:sqlite_path("plugins.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    ok = create_tables(Db),
    {ok, #state{db = Db}}.

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
        {error, Code} ->
            logger:error("[project_plugins_store] SQLite step error: ~p", [Code]),
            {error, Code};
        _ -> step_until_done(Stmt)
    end.

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS plugins (
            plugin_id         TEXT PRIMARY KEY,
            name              TEXT NOT NULL,
            oci_image         TEXT,
            installed_version TEXT,
            license_id        TEXT,
            installed_at      INTEGER,
            upgraded_at       INTEGER,
            removed_at        INTEGER,
            status            INTEGER DEFAULT 0,
            status_label      TEXT DEFAULT ''
        );"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    run_migrations(Db),
    ok.

run_migrations(Db) ->
    %% Migration 1: Add started_at and stopped_at columns for execution tracking
    add_column_if_missing(Db, "plugins", "started_at", "INTEGER"),
    add_column_if_missing(Db, "plugins", "stopped_at", "INTEGER"),
    ok.

add_column_if_missing(Db, Table, Column, Type) ->
    Sql = ["PRAGMA table_info(", Table, ");"],
    {ok, Stmt} = esqlite3:prepare(Db, iolist_to_binary(Sql)),
    Rows = esqlite3:fetchall(Stmt),
    HasColumn = lists:any(fun(Row) -> lists:nth(2, Row) =:= list_to_binary(Column) end, Rows),
    case HasColumn of
        true -> ok;
        false ->
            AlterSql = iolist_to_binary([
                "ALTER TABLE ", Table, " ADD COLUMN ", Column, " ", Type, ";"
            ]),
            ok = esqlite3:exec(Db, AlterSql)
    end.
