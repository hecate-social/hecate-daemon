-module(query_reputation_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% Initialize SQLite database for read models
    DbPath = application:get_env(query_reputation, db_path, "data/query_reputation.db"),
    {ok, Conn} = esqlite3:open(DbPath),

    %% Create tables
    ok = create_tables(Conn),

    %% Store connection in application environment
    application:set_env(query_reputation, db_conn, Conn),

    %% Start supervisor
    query_reputation_sup:start_link().

stop(_State) ->
    %% Close database
    case application:get_env(query_reputation, db_conn) of
        {ok, Conn} -> esqlite3:close(Conn);
        undefined -> ok
    end,
    ok.

%% Internal functions

create_tables(Conn) ->
    %% === LOCAL TABLES (from MY domain events) ===

    %% RPC calls I tracked (from my rpc_call_tracked_v1 events)
    RpcCallsTable = <<"
        CREATE TABLE IF NOT EXISTS rpc_calls (
            call_id TEXT PRIMARY KEY,
            caller_identity TEXT NOT NULL,
            callee_identity TEXT NOT NULL,
            procedure TEXT NOT NULL,
            call_duration_ms INTEGER NOT NULL,
            success INTEGER NOT NULL,
            error_reason TEXT,
            metadata TEXT,
            tracked_at INTEGER NOT NULL,
            FOREIGN KEY (caller_identity) REFERENCES agents(agent_identity),
            FOREIGN KEY (callee_identity) REFERENCES agents(agent_identity)
        )
    ">>,
    esqlite3:exec(Conn, RpcCallsTable),

    %% Reputation table (aggregated view)
    ReputationTable = <<"
        CREATE TABLE IF NOT EXISTS agent_reputation (
            agent_identity TEXT PRIMARY KEY,
            total_calls INTEGER DEFAULT 0,
            successful_calls INTEGER DEFAULT 0,
            failed_calls INTEGER DEFAULT 0,
            total_duration_ms INTEGER DEFAULT 0,
            disputes_flagged INTEGER DEFAULT 0,
            disputes_upheld INTEGER DEFAULT 0,
            reputation_score REAL DEFAULT 0.0,
            last_updated INTEGER NOT NULL
        )
    ">>,
    esqlite3:exec(Conn, ReputationTable),

    %% Disputes I flagged (from my dispute_flagged_v1 events)
    DisputesTable = <<"
        CREATE TABLE IF NOT EXISTS disputes (
            dispute_id TEXT PRIMARY KEY,
            call_id TEXT NOT NULL,
            flagger_identity TEXT NOT NULL,
            reason TEXT NOT NULL,
            evidence TEXT,
            resolution TEXT,
            resolver_identity TEXT,
            notes TEXT,
            flagged_at INTEGER NOT NULL,
            resolved_at INTEGER,
            FOREIGN KEY (call_id) REFERENCES rpc_calls(call_id)
        )
    ">>,
    esqlite3:exec(Conn, DisputesTable),

    %% === REMOTE TABLES (from mesh facts about ME) ===

    %% Disputes AGAINST me (from filtered mesh facts: dispute.flagged where accused ∈ MY_IDENTITIES)
    %% IMPORTANT: These are disputes other agents filed against my services
    DisputesAgainstMeTable = <<"
        CREATE TABLE IF NOT EXISTS disputes_against_me (
            dispute_id TEXT PRIMARY KEY,
            call_id TEXT,
            flagger_identity TEXT NOT NULL,
            my_identity TEXT NOT NULL,
            reason TEXT NOT NULL,
            evidence TEXT,
            resolution TEXT,
            resolver_identity TEXT,
            notes TEXT,
            flagged_at INTEGER NOT NULL,
            resolved_at INTEGER,
            discovered_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
    ">>,
    esqlite3:exec(Conn, DisputesAgainstMeTable),

    %% Create indexes for local tables
    esqlite3:exec(Conn, <<"CREATE INDEX IF NOT EXISTS idx_rpc_calls_caller ON rpc_calls(caller_identity)">>),
    esqlite3:exec(Conn, <<"CREATE INDEX IF NOT EXISTS idx_rpc_calls_callee ON rpc_calls(callee_identity)">>),
    esqlite3:exec(Conn, <<"CREATE INDEX IF NOT EXISTS idx_disputes_call ON disputes(call_id)">>),

    %% Create indexes for remote tables
    esqlite3:exec(Conn, <<"CREATE INDEX IF NOT EXISTS idx_disputes_against_me_identity ON disputes_against_me(my_identity)">>),
    esqlite3:exec(Conn, <<"CREATE INDEX IF NOT EXISTS idx_disputes_against_me_flagger ON disputes_against_me(flagger_identity)">>),
    esqlite3:exec(Conn, <<"CREATE INDEX IF NOT EXISTS idx_disputes_against_me_flagged_at ON disputes_against_me(flagged_at DESC)">>),

    ok.
