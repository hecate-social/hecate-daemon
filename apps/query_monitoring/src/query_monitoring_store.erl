%%% @doc SQLite persistence for monitoring read models.
%%%
%%% Three tables:
%%%   - monitorings: one row per division's monitoring process
%%%   - health_checks: one row per registered health check
%%%   - incidents: one row per raised incident
%%% @end
-module(query_monitoring_store).
-behaviour(gen_server).

-include_lib("monitor_division/include/monitoring_status.hrl").

-export([start_link/0, init_schema/0]).
-export([execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(DB_PATH, "data/query_monitoring.db").

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init_schema() ->
    gen_server:call(?MODULE, init_schema).

execute(Sql) -> execute(Sql, []).
execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

query(Sql) -> query(Sql, []).
query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

%% gen_server callbacks

init([]) ->
    filelib:ensure_dir(?DB_PATH),
    {ok, Db} = esqlite3:open(?DB_PATH),
    ok = esqlite3:exec("PRAGMA journal_mode=WAL;", Db),
    {ok, #{db => Db}}.

handle_call(init_schema, _From, #{db := Db} = State) ->
    Sql = "CREATE TABLE IF NOT EXISTS monitorings ("
          "  division_id TEXT PRIMARY KEY,"
          "  status INTEGER NOT NULL DEFAULT 1,"
          "  status_label TEXT DEFAULT 'Initiated',"
          "  started_at INTEGER,"
          "  started_by TEXT,"
          "  paused_at INTEGER,"
          "  pause_reason TEXT,"
          "  completed_at INTEGER"
          ");"
          "CREATE TABLE IF NOT EXISTS health_checks ("
          "  check_id TEXT PRIMARY KEY,"
          "  division_id TEXT NOT NULL,"
          "  check_name TEXT NOT NULL,"
          "  check_type TEXT,"
          "  endpoint TEXT,"
          "  interval_ms INTEGER,"
          "  registered_at INTEGER NOT NULL,"
          "  last_status TEXT,"
          "  last_latency_ms INTEGER,"
          "  last_checked_at INTEGER"
          ");"
          "CREATE TABLE IF NOT EXISTS incidents ("
          "  incident_id TEXT PRIMARY KEY,"
          "  division_id TEXT NOT NULL,"
          "  incident_title TEXT NOT NULL,"
          "  severity TEXT,"
          "  description TEXT,"
          "  raised_at INTEGER NOT NULL"
          ");"
          "CREATE INDEX IF NOT EXISTS idx_monitorings_status ON monitorings(status);"
          "CREATE INDEX IF NOT EXISTS idx_health_checks_division ON health_checks(division_id);"
          "CREATE INDEX IF NOT EXISTS idx_incidents_division ON incidents(division_id);"
          "CREATE INDEX IF NOT EXISTS idx_incidents_severity ON incidents(severity);",
    ok = esqlite3:exec(Sql, Db),
    {reply, ok, State};

handle_call({execute, Sql, Params}, _From, #{db := Db} = State) ->
    case esqlite3:q(Sql, Params, Db) of
        [] -> {reply, ok, State};
        {error, _} = Err -> {reply, Err, State};
        _Rows -> {reply, ok, State}
    end;

handle_call({query, Sql, Params}, _From, #{db := Db} = State) ->
    case esqlite3:q(Sql, Params, Db) of
        {error, _} = Err -> {reply, Err, State};
        Rows when is_list(Rows) -> {reply, {ok, Rows}, State}
    end;

handle_call(_Req, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
