%%% @doc Test helper: proxy gen_server that stands in for query_ventures_store.
%%% Registers as query_ventures_store so projections and queries work unchanged.
%%% Uses a temp SQLite database that gets cleaned up after tests.
-module(test_store_proxy).
-behaviour(gen_server).

-export([start/1, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference(), path :: string()}).

-spec start(string()) -> {ok, pid()} | {error, term()}.
start(DbPath) ->
    gen_server:start({local, query_ventures_store}, ?MODULE, DbPath, []).

-spec stop() -> ok.
stop() ->
    gen_server:stop(query_ventures_store).

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
            {reply, {ok, Rows}, State};
        {error, _} = Err ->
            {reply, Err, State}
    end;

handle_call({query, Sql, Params}, _From, #state{db = Db} = State) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} ->
            ok = esqlite3:bind(Stmt, Params),
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

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS ventures (
            venture_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            brief TEXT,
            status INTEGER NOT NULL DEFAULT 1,
            status_label TEXT DEFAULT 'New',
            repos TEXT,
            skills TEXT,
            context_map TEXT,
            initiated_at INTEGER NOT NULL,
            initiated_by TEXT
        );",
        "CREATE INDEX IF NOT EXISTS idx_ventures_status ON ventures(status);",
        "CREATE INDEX IF NOT EXISTS idx_ventures_name ON ventures(name);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
