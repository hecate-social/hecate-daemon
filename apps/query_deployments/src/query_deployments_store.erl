%%% @doc SQLite persistence for deployment read models.
%%%
%%% Three tables:
%%%   - deployments: one row per division's deployment process
%%%   - releases: one row per deployed release
%%%   - rollout_stages: one row per rollout stage
%%% @end
-module(query_deployments_store).
-behaviour(gen_server).

-include_lib("deploy_division/include/deployment_status.hrl").

-export([start_link/0, init_schema/0]).
-export([execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(DB_PATH, "data/query_deployments.db").

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
    Sql = "CREATE TABLE IF NOT EXISTS deployments ("
          "  division_id TEXT PRIMARY KEY,"
          "  status INTEGER NOT NULL DEFAULT 1,"
          "  status_label TEXT DEFAULT 'Initiated',"
          "  started_at INTEGER,"
          "  started_by TEXT,"
          "  paused_at INTEGER,"
          "  pause_reason TEXT,"
          "  completed_at INTEGER"
          ");"
          "CREATE TABLE IF NOT EXISTS releases ("
          "  release_id TEXT PRIMARY KEY,"
          "  division_id TEXT NOT NULL,"
          "  release_name TEXT NOT NULL,"
          "  release_version TEXT,"
          "  target_env TEXT,"
          "  deployed_by TEXT,"
          "  deployed_at INTEGER NOT NULL"
          ");"
          "CREATE TABLE IF NOT EXISTS rollout_stages ("
          "  stage_id TEXT PRIMARY KEY,"
          "  division_id TEXT NOT NULL,"
          "  release_id TEXT NOT NULL,"
          "  stage_name TEXT NOT NULL,"
          "  stage_percentage INTEGER,"
          "  description TEXT,"
          "  staged_at INTEGER NOT NULL"
          ");"
          "CREATE INDEX IF NOT EXISTS idx_deployments_status ON deployments(status);"
          "CREATE INDEX IF NOT EXISTS idx_releases_division ON releases(division_id);"
          "CREATE INDEX IF NOT EXISTS idx_rollout_stages_division ON rollout_stages(division_id);"
          "CREATE INDEX IF NOT EXISTS idx_rollout_stages_release ON rollout_stages(release_id);",
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
