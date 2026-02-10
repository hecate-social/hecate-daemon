%%% @doc SQLite persistence for testing read models.
%%%
%%% Three tables:
%%%   - testings: one row per division's testing process
%%%   - test_suites: one row per test suite run
%%%   - test_results: one row per test result
%%% @end
-module(query_tests_store).
-behaviour(gen_server).

-include_lib("test_division/include/testing_status.hrl").

-export([start_link/0, init_schema/0]).
-export([execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(DB_PATH, "data/query_tests.db").

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
    Sql = "CREATE TABLE IF NOT EXISTS testings ("
          "  division_id TEXT PRIMARY KEY,"
          "  status INTEGER NOT NULL DEFAULT 1,"
          "  status_label TEXT DEFAULT 'Initiated',"
          "  started_at INTEGER,"
          "  started_by TEXT,"
          "  paused_at INTEGER,"
          "  pause_reason TEXT,"
          "  completed_at INTEGER"
          ");"
          "CREATE TABLE IF NOT EXISTS test_suites ("
          "  suite_id TEXT PRIMARY KEY,"
          "  division_id TEXT NOT NULL,"
          "  suite_name TEXT NOT NULL,"
          "  suite_type TEXT,"
          "  target_module TEXT,"
          "  run_at INTEGER NOT NULL"
          ");"
          "CREATE TABLE IF NOT EXISTS test_results ("
          "  result_id TEXT PRIMARY KEY,"
          "  division_id TEXT NOT NULL,"
          "  suite_id TEXT NOT NULL,"
          "  test_name TEXT NOT NULL,"
          "  status TEXT,"
          "  details TEXT,"
          "  recorded_at INTEGER NOT NULL"
          ");"
          "CREATE INDEX IF NOT EXISTS idx_testings_status ON testings(status);"
          "CREATE INDEX IF NOT EXISTS idx_test_suites_division ON test_suites(division_id);"
          "CREATE INDEX IF NOT EXISTS idx_test_results_division ON test_results(division_id);"
          "CREATE INDEX IF NOT EXISTS idx_test_results_suite ON test_results(suite_id);",
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
