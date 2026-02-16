%%% @doc Consolidated SQLite store for all node lifecycle read models.
%%%
%%% Contains 13 tables across identity, capabilities, mesh connections,
%%% endorsements, subscriptions, and UCAN domains.
-module(query_node_lifecycle_store).
-behaviour(gen_server).

-export([start_link/0, db/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: reference()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Get the shared database connection.
db() ->
    gen_server:call(?MODULE, get_db).

%% @doc Execute a write SQL statement (INSERT, UPDATE, DELETE).
execute(Sql) -> execute(Sql, []).
execute(Sql, Params) -> gen_server:call(?MODULE, {execute, Sql, Params}).

%% @doc Execute a read SQL query, returns {ok, Rows} or {error, Reason}.
query(Sql) -> query(Sql, []).
query(Sql, Params) -> gen_server:call(?MODULE, {query, Sql, Params}).

init([]) ->
    DbPath = shared_paths:db_path("query_node_lifecycle.db"),
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

    %% === Identity tables ===
    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS identities (
        mri TEXT PRIMARY KEY,
        public_key TEXT NOT NULL,
        key_type TEXT NOT NULL,
        metadata TEXT DEFAULT '{}',
        registered_at INTEGER NOT NULL,
        updated_at INTEGER
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_identities_registered_at ON identities(registered_at)"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS remote_identities (
        mri TEXT PRIMARY KEY,
        public_key TEXT,
        key_type TEXT,
        metadata TEXT DEFAULT '{}',
        registered_at INTEGER,
        updated_at INTEGER,
        discovered_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_remote_identities_last_seen ON remote_identities(last_seen_at DESC)"),

    %% === Capability tables ===
    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS capabilities (
        mri TEXT PRIMARY KEY,
        agent_id TEXT NOT NULL,
        tags TEXT DEFAULT '[]',
        description TEXT,
        demo_procedure TEXT,
        metadata TEXT DEFAULT '{}',
        announced_at INTEGER NOT NULL,
        updated_at INTEGER,
        retracted_at INTEGER,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_capabilities_agent ON capabilities(agent_id)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_capabilities_active ON capabilities(mri) WHERE retracted_at IS NULL"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS remote_capabilities (
        mri TEXT PRIMARY KEY,
        agent_id TEXT NOT NULL,
        tags TEXT DEFAULT '[]',
        description TEXT,
        demo_procedure TEXT,
        metadata TEXT DEFAULT '{}',
        announced_at INTEGER,
        discovered_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL,
        latency_ms INTEGER,
        last_latency_check INTEGER
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_remote_caps_agent ON remote_capabilities(agent_id)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_remote_caps_last_seen ON remote_capabilities(last_seen_at DESC)"),

    %% === Connection tables (was followers) ===
    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS connections (
        source_node TEXT NOT NULL,
        target_node TEXT NOT NULL,
        connected_at INTEGER NOT NULL,
        PRIMARY KEY (source_node, target_node)
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_connections_source ON connections(source_node)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_connections_target ON connections(target_node)"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS my_connections (
        remote_node TEXT NOT NULL,
        my_identity TEXT NOT NULL,
        connected_at INTEGER NOT NULL,
        discovered_at INTEGER NOT NULL,
        PRIMARY KEY (remote_node, my_identity)
    )"),

    %% === Endorsement tables ===
    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS endorsements (
        endorser_identity TEXT NOT NULL,
        capability_mri TEXT NOT NULL,
        comment TEXT,
        endorsed_at INTEGER NOT NULL,
        revoked_at INTEGER,
        PRIMARY KEY (endorser_identity, capability_mri)
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_endorsements_cap ON endorsements(capability_mri)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_endorsements_active ON endorsements(endorser_identity, capability_mri) WHERE revoked_at IS NULL"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS my_endorsements (
        endorser_identity TEXT NOT NULL,
        my_capability_mri TEXT NOT NULL,
        comment TEXT,
        endorsed_at INTEGER NOT NULL,
        revoked_at INTEGER,
        discovered_at INTEGER NOT NULL,
        PRIMARY KEY (endorser_identity, my_capability_mri)
    )"),

    %% === Subscription tables ===
    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS subscriptions (
        agent_identity TEXT NOT NULL,
        topic TEXT NOT NULL,
        filter TEXT,
        subscribed_at INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (agent_identity, topic)
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_subs_agent ON subscriptions(agent_identity)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_subs_active ON subscriptions(active)"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS my_subscribers (
        subscriber_identity TEXT NOT NULL,
        my_identity TEXT NOT NULL,
        topic TEXT NOT NULL,
        filter TEXT,
        subscribed_at INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        discovered_at INTEGER NOT NULL,
        PRIMARY KEY (subscriber_identity, my_identity, topic)
    )"),

    %% === UCAN tables ===
    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS ucan_grants (
        capability_id TEXT PRIMARY KEY,
        issuer TEXT NOT NULL,
        audience TEXT NOT NULL,
        resource TEXT NOT NULL,
        actions TEXT NOT NULL DEFAULT '[]',
        expires_at INTEGER NOT NULL,
        granted_at INTEGER NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        revoked_at INTEGER
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_ucan_issuer ON ucan_grants(issuer)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_ucan_audience ON ucan_grants(audience)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_ucan_revoked ON ucan_grants(revoked)"),

    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS received_ucans (
        capability_id TEXT PRIMARY KEY,
        issuer TEXT NOT NULL,
        my_identity TEXT NOT NULL,
        resource TEXT NOT NULL,
        actions TEXT NOT NULL DEFAULT '[]',
        expires_at INTEGER NOT NULL,
        granted_at INTEGER NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        revoked_at INTEGER,
        discovered_at INTEGER NOT NULL,
        token_cid TEXT
    )"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_recv_ucan_issuer ON received_ucans(issuer)"),
    ok = esqlite3:exec(Db, "CREATE INDEX IF NOT EXISTS idx_recv_ucan_identity ON received_ucans(my_identity)"),

    %% === Connectors table ===
    ok = esqlite3:exec(Db, "CREATE TABLE IF NOT EXISTS connectors (
        connector_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        socket_path TEXT,
        allowed_routes TEXT DEFAULT 'all',
        status INTEGER NOT NULL DEFAULT 0,
        registered_at INTEGER NOT NULL,
        revoked_at INTEGER,
        suspended_at INTEGER,
        activated_at INTEGER
    )"),

    ok.
