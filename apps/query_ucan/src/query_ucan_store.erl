%%% @doc SQLite store for UCAN capability read models
-module(query_ucan_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, query/1]).
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
    gen_server:call(?MODULE, {execute, Sql}).

query(Sql) ->
    gen_server:call(?MODULE, {query, Sql}).

%% Callbacks

init([]) ->
    DataDir = application:get_env(hecate, data_dir, "~/.hecate"),
    DbPath = filename:join([DataDir, "query_ucan.db"]),
    filelib:ensure_dir(DbPath),

    {ok, Db} = esqlite3:open(DbPath),
    {ok, #state{db = Db}}.

handle_call(init_schema, _From, State) ->
    %% === LOCAL TABLES (from MY domain events) ===

    %% UCAN tokens I granted (from my capability_granted_v1 events)
    LocalSchemas = [
        <<"CREATE TABLE IF NOT EXISTS capabilities (
            capability_id TEXT PRIMARY KEY,
            issuer TEXT NOT NULL,
            audience TEXT NOT NULL,
            resource TEXT NOT NULL,
            actions TEXT NOT NULL,
            expires_at INTEGER NOT NULL,
            granted_at INTEGER NOT NULL,
            revoked INTEGER DEFAULT 0,
            revoked_at INTEGER
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_capabilities_issuer
           ON capabilities(issuer)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_capabilities_audience
           ON capabilities(audience)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_capabilities_revoked
           ON capabilities(revoked)">>
    ],

    %% === REMOTE TABLES (from mesh facts about ME) ===

    %% UCAN tokens granted TO me (from filtered mesh facts: ucan.granted where audience ∈ MY_IDENTITIES)
    %% SECURITY-CRITICAL: These are capabilities I can use to perform actions
    RemoteSchemas = [
        <<"CREATE TABLE IF NOT EXISTS received_capabilities (
            capability_id TEXT PRIMARY KEY,
            issuer TEXT NOT NULL,
            my_identity TEXT NOT NULL,
            resource TEXT NOT NULL,
            actions TEXT NOT NULL,
            expires_at INTEGER NOT NULL,
            granted_at INTEGER NOT NULL,
            revoked INTEGER DEFAULT 0,
            revoked_at INTEGER,
            discovered_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            token_cid TEXT
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_received_capabilities_issuer
           ON received_capabilities(issuer)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_received_capabilities_my_identity
           ON received_capabilities(my_identity)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_received_capabilities_resource
           ON received_capabilities(resource)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_received_capabilities_revoked
           ON received_capabilities(revoked)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_received_capabilities_expires
           ON received_capabilities(expires_at)">>
    ],

    AllSchemas = LocalSchemas ++ RemoteSchemas,
    Results = [esqlite3:exec(State#state.db, Sql) || Sql <- AllSchemas],
    case lists:any(fun(R) -> R =/= ok end, Results) of
        true -> {reply, {error, schema_init_failed}, State};
        false -> {reply, ok, State}
    end;

handle_call({execute, Sql}, _From, State) ->
    Result = esqlite3:exec(State#state.db, Sql),
    {reply, Result, State};

handle_call({query, Sql}, _From, State) ->
    %% esqlite3:q returns [[col1, col2,...], ...] or {error, Reason}
    %% Wrap in {ok, Rows} for consistency
    case esqlite3:q(State#state.db, Sql) of
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
