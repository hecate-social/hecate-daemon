%%% @doc SQLite store for query_snake_duel read models.
%%% Tables: matches, leaderboard
-module(query_snake_duel_store).
-behaviour(gen_server).

-export([start_link/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-export([record_match/1]).

-record(state, {db :: reference()}).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    DbPath = shared_paths:db_path("query_snake_duel.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    ok = create_tables(Db),
    {ok, #state{db = Db}}.

-spec execute(iodata()) -> ok | {error, term()}.
execute(Sql) ->
    gen_server:call(?MODULE, {execute, Sql, []}).

-spec execute(iodata(), [term()]) -> ok | {error, term()}.
execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

-spec query(iodata()) -> {ok, [list()]} | {error, term()}.
query(Sql) ->
    gen_server:call(?MODULE, {query, Sql, []}).

-spec query(iodata(), [term()]) -> {ok, [list()]} | {error, term()}.
query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

%% @doc Record a completed match result into the read model.
-spec record_match(map()) -> ok.
record_match(#{match_id := MatchId, winner := Winner,
               af1 := AF1, af2 := AF2, tick_ms := TickMs,
               score1 := Score1, score2 := Score2,
               ticks := Ticks, started_at := StartedAt}) ->
    EndedAt = erlang:system_time(millisecond),
    WinnerBin = atom_to_binary(Winner),
    Sql = "INSERT OR REPLACE INTO matches
           (match_id, winner, af1, af2, tick_ms, score1, score2, ticks, started_at, ended_at)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
    execute(Sql, [MatchId, WinnerBin, AF1, AF2, TickMs,
                  Score1, Score2, Ticks, StartedAt, EndedAt]).

handle_call({execute, Sql, Params}, _From, #state{db = Db} = State) ->
    case Params of
        [] ->
            Result = esqlite3:exec(Db, Sql),
            {reply, Result, State};
        _ ->
            case esqlite3:prepare(Db, Sql) of
                {ok, Stmt} ->
                    ok = esqlite3:bind(Stmt, Params),
                    step_until_done(Stmt),
                    {reply, ok, State};
                {error, _} = Err ->
                    {reply, Err, State}
            end
    end;

handle_call({query, Sql, Params}, _From, #state{db = Db} = State) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} ->
            case Params of
                [] -> ok;
                _ -> ok = esqlite3:bind(Stmt, Params)
            end,
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

terminate(_Reason, #state{db = Db}) ->
    esqlite3:close(Db).

%% Internal

step_until_done(Stmt) ->
    case esqlite3:step(Stmt) of
        '$done' -> ok;
        {row, _} -> step_until_done(Stmt);
        ok -> ok;
        {error, Code} ->
            logger:error("[query_snake_duel_store] SQLite step error: ~p", [Code]),
            {error, Code}
    end.

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS matches (
            match_id TEXT PRIMARY KEY,
            winner TEXT NOT NULL,
            af1 INTEGER NOT NULL,
            af2 INTEGER NOT NULL,
            tick_ms INTEGER NOT NULL,
            score1 INTEGER NOT NULL DEFAULT 0,
            score2 INTEGER NOT NULL DEFAULT 0,
            ticks INTEGER NOT NULL DEFAULT 0,
            started_at INTEGER NOT NULL,
            ended_at INTEGER NOT NULL
        );",
        "CREATE INDEX IF NOT EXISTS idx_matches_winner ON matches(winner);",
        "CREATE INDEX IF NOT EXISTS idx_matches_ended_at ON matches(ended_at);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
