%%% @doc SQLite store for identity read models
-module(query_identities_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    db :: term()
}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init_schema() ->
    gen_server:call(?MODULE, init_schema).

execute(Sql) ->
    execute(Sql, []).

execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

query(Sql) ->
    query(Sql, []).

query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

%% Callbacks

init([]) ->
    DataDir = application:get_env(hecate, data_dir, "~/.hecate"),
    DbPath = filename:join([DataDir, "query_identities.db"]),
    filelib:ensure_dir(DbPath),

    {ok, Db} = esqlite3:open(DbPath),
    {ok, #state{db = Db}}.

handle_call(init_schema, _From, State) ->
    %% Local identities - registered by THIS gateway/services
    LocalSchemas = [
        <<"CREATE TABLE IF NOT EXISTS identities (
            mri TEXT PRIMARY KEY,
            public_key TEXT NOT NULL,
            key_type TEXT NOT NULL,
            metadata TEXT,
            registered_at INTEGER NOT NULL,
            updated_at INTEGER
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_identities_registered
           ON identities(registered_at)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_identities_updated
           ON identities(updated_at)">>
    ],

    %% Remote identities - discovered from OTHER agents via mesh
    %% Used for identity lookup/verification queries
    RemoteSchemas = [
        <<"CREATE TABLE IF NOT EXISTS remote_identities (
            mri TEXT PRIMARY KEY,
            public_key TEXT NOT NULL,
            key_type TEXT NOT NULL,
            metadata TEXT,
            registered_at INTEGER NOT NULL,
            updated_at INTEGER,
            discovered_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            last_seen_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_remote_identities_registered
           ON remote_identities(registered_at)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_remote_identities_last_seen
           ON remote_identities(last_seen_at DESC)">>
    ],

    AllSchemas = LocalSchemas ++ RemoteSchemas,
    Results = [esqlite3:exec(State#state.db, Sql) || Sql <- AllSchemas],
    case lists:any(fun(R) -> R =/= ok end, Results) of
        true -> {reply, {error, schema_init_failed}, State};
        false -> {reply, ok, State}
    end;

handle_call({execute, Sql, Params}, _From, State) ->
    %% Use esqlite3:q for parameterized queries
    %% Note: esqlite3:q returns [] for INSERT/UPDATE (no rows), not {ok, _}
    case esqlite3:q(State#state.db, Sql, Params) of
        Rows when is_list(Rows) -> {reply, ok, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end;

handle_call({query, Sql, Params}, _From, State) ->
    %% esqlite3:q returns [[col1, col2,...], ...] or {error, Reason}
    %% Wrap in {ok, Rows} for consistency
    case esqlite3:q(State#state.db, Sql, Params) of
        Rows when is_list(Rows) -> {reply, {ok, Rows}, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    esqlite3:close(State#state.db),
    ok.
