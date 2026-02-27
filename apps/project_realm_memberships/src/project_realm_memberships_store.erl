%%% @doc SQLite store for realm memberships read model.
-module(project_realm_memberships_store).
-behaviour(gen_server).

-export([start_link/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

execute(Sql) -> execute(Sql, []).
execute(Sql, Params) -> gen_server:call(?MODULE, {execute, Sql, Params}).

query(Sql) -> query(Sql, []).
query(Sql, Params) -> gen_server:call(?MODULE, {query, Sql, Params}).

init([]) ->
    DbPath = shared_paths:sqlite_path("project_realm_memberships.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = create_tables(Db),
    {ok, #state{db = Db}}.

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

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS realm_memberships (
        membership_id TEXT PRIMARY KEY,
        realm_id TEXT,
        realm_url TEXT NOT NULL,
        oauth_account TEXT,
        oauth_provider TEXT,
        status TEXT NOT NULL DEFAULT 'initiated',
        initiated_at INTEGER NOT NULL,
        confirmed_at INTEGER,
        revoked_at INTEGER
    )"),

    ok.
