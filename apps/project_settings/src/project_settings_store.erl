%%% @doc SQLite store for settings read models.
%%%
%%% Two tables: settings (singleton) and api_keys.
-module(project_settings_store).
-behaviour(gen_server).

-export([start_link/0, db/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

db() ->
    gen_server:call(?MODULE, get_db).

execute(Sql) -> execute(Sql, []).
execute(Sql, Params) -> gen_server:call(?MODULE, {execute, Sql, Params}).

query(Sql) -> query(Sql, []).
query(Sql, Params) -> gen_server:call(?MODULE, {query, Sql, Params}).

init([]) ->
    DbPath = shared_paths:sqlite_path("project_settings.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = create_tables(Db),
    {ok, #state{db = Db}}.

handle_call(get_db, _From, #state{db = Db} = State) ->
    {reply, {ok, Db}, State};
handle_call({execute, Sql, Params}, _From, #state{db = Db} = State) ->
    Result = case Params of
        [] -> esqlite3:exec(Db, Sql);
        _ ->
            case esqlite3:q(Db, Sql, Params) of
                Rows when is_list(Rows) -> ok;
                {error, _} = Err -> Err
            end
    end,
    {reply, Result, State};
handle_call({query, Sql, Params}, _From, #state{db = Db} = State) ->
    Result = case esqlite3:q(Db, Sql, Params) of
        Rows when is_list(Rows) -> {ok, Rows};
        {error, _} = Err -> Err
    end,
    {reply, Result, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.

terminate(_Reason, #state{db = Db}) ->
    esqlite3:close(Db).

%% ===================================================================
%% Internal
%% ===================================================================

create_tables(Db) ->
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL"),
    ok = esqlite3:exec(Db, "PRAGMA foreign_keys=ON"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        linux_user TEXT NOT NULL,
        hostname TEXT NOT NULL,
        github_user TEXT,
        hecate_user_id TEXT NOT NULL,
        realm TEXT,
        paired INTEGER NOT NULL DEFAULT 0,
        paired_at INTEGER,
        preferences TEXT NOT NULL DEFAULT '{}',
        status INTEGER NOT NULL DEFAULT 0,
        initiated_at INTEGER NOT NULL
    )"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS api_keys (
        provider TEXT PRIMARY KEY,
        api_key TEXT NOT NULL,
        label TEXT NOT NULL,
        configured_at INTEGER NOT NULL
    )"),

    ok.
