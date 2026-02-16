%%% @doc SQLite store for query_snake_gladiators read models.
%%% Tables: stables, champions, generation_log
-module(query_snake_gladiators_store).
-behaviour(gen_server).

-export([start_link/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Domain-specific write helpers
-export([record_stable/1, update_stable_progress/1, complete_stable/1,
         record_champion/1, record_generation/1]).
-export([promote_champion/1, update_hero_record/1]).

%% Domain-specific read helpers
-export([get_stables/0, get_stable_by_id/1, get_champion/1, get_training_history/1]).
-export([get_heroes/0, get_hero/1]).

-record(state, {db :: reference()}).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    DbPath = shared_paths:db_path("query_snake_gladiators.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    ok = create_tables(Db),
    {ok, #state{db = Db}}.

%%--------------------------------------------------------------------
%% Generic SQL API
%%--------------------------------------------------------------------

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

%%--------------------------------------------------------------------
%% Domain write helpers
%%--------------------------------------------------------------------

-spec record_stable(map()) -> ok.
record_stable(#{stable_id := StableId, population_size := PopSize,
                 max_generations := MaxGen, opponent_af := OppAF,
                 episodes_per_eval := Episodes, started_at := StartedAt} = Data) ->
    FitnessWeights = maps:get(fitness_weights, Data, null),
    Sql = "INSERT INTO stables
           (stable_id, status, population_size, max_generations,
            opponent_af, episodes_per_eval, started_at, fitness_weights)
           VALUES (?1, 'training', ?2, ?3, ?4, ?5, ?6, ?7)",
    execute(Sql, [StableId, PopSize, MaxGen, OppAF, Episodes, StartedAt, FitnessWeights]).

-spec update_stable_progress(map()) -> ok.
update_stable_progress(#{stable_id := StableId, best_fitness := BestFit,
                          generations_completed := GenDone}) ->
    Sql = "UPDATE stables SET best_fitness = ?1, generations_completed = ?2
           WHERE stable_id = ?3",
    execute(Sql, [BestFit, GenDone, StableId]).

-spec complete_stable(map()) -> ok.
complete_stable(#{stable_id := StableId, status := Status}) ->
    StatusBin = atom_to_binary(Status),
    Now = erlang:system_time(millisecond),
    Sql = "UPDATE stables SET status = ?1, completed_at = ?2
           WHERE stable_id = ?3",
    execute(Sql, [StatusBin, Now, StableId]).

-spec record_champion(map()) -> ok.
record_champion(#{stable_id := StableId, network_json := NetJson,
                   fitness := Fitness, generation := Gen,
                   wins := Wins, losses := Losses, draws := Draws}) ->
    Now = erlang:system_time(millisecond),
    Sql = "INSERT OR REPLACE INTO champions
           (stable_id, network_json, fitness, generation,
            wins, losses, draws, exported_at)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
    execute(Sql, [StableId, NetJson, Fitness, Gen, Wins, Losses, Draws, Now]).

-spec record_generation(map()) -> ok.
record_generation(#{stable_id := StableId, generation := Gen,
                     best_fitness := Best, avg_fitness := Avg,
                     worst_fitness := Worst}) ->
    Now = erlang:system_time(millisecond),
    Sql = "INSERT OR REPLACE INTO generation_log
           (stable_id, generation, best_fitness, avg_fitness,
            worst_fitness, timestamp)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    execute(Sql, [StableId, Gen, Best, Avg, Worst, Now]).

-spec promote_champion(map()) -> ok.
promote_champion(#{hero_id := HeroId, name := Name, stable_id := StableId,
                    network_json := NetJson, fitness := Fitness,
                    generation := Gen, promoted_at := PromotedAt}) ->
    Sql = "INSERT INTO heroes
           (hero_id, name, network_json, fitness, origin_stable_id,
            generation, wins, losses, draws, promoted_at)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0, 0, 0, ?7)",
    execute(Sql, [HeroId, Name, NetJson, Fitness, Gen, StableId, PromotedAt]).

-spec update_hero_record(map()) -> ok.
update_hero_record(#{hero_id := HeroId, wins := Wins,
                      losses := Losses, draws := Draws}) ->
    Sql = "UPDATE heroes SET wins = ?1, losses = ?2, draws = ?3
           WHERE hero_id = ?4",
    execute(Sql, [Wins, Losses, Draws, HeroId]).

%%--------------------------------------------------------------------
%% Domain read helpers
%%--------------------------------------------------------------------

-spec get_stables() -> {ok, [map()]}.
get_stables() ->
    {ok, Rows} = query(
        "SELECT stable_id, status, population_size, max_generations,
                opponent_af, episodes_per_eval, best_fitness,
                generations_completed, started_at, completed_at,
                fitness_weights
         FROM stables ORDER BY started_at DESC"),
    {ok, [stable_row_to_map(R) || R <- Rows]}.

-spec get_stable_by_id(binary()) -> {ok, map()} | {error, not_found}.
get_stable_by_id(StableId) ->
    {ok, Rows} = query(
        "SELECT stable_id, status, population_size, max_generations,
                opponent_af, episodes_per_eval, best_fitness,
                generations_completed, started_at, completed_at,
                fitness_weights
         FROM stables WHERE stable_id = ?1", [StableId]),
    case Rows of
        [Row] -> {ok, stable_row_to_map(Row)};
        [] -> {error, not_found}
    end.

-spec get_champion(binary()) -> {ok, map()} | {error, not_found}.
get_champion(StableId) ->
    {ok, Rows} = query(
        "SELECT stable_id, network_json, fitness, generation,
                wins, losses, draws, exported_at
         FROM champions WHERE stable_id = ?1", [StableId]),
    case Rows of
        [Row] -> {ok, champion_row_to_map(Row)};
        [] -> {error, not_found}
    end.

-spec get_training_history(binary()) -> {ok, [map()]}.
get_training_history(StableId) ->
    {ok, Rows} = query(
        "SELECT stable_id, generation, best_fitness, avg_fitness,
                worst_fitness, timestamp
         FROM generation_log WHERE stable_id = ?1
         ORDER BY generation ASC", [StableId]),
    {ok, [gen_row_to_map(R) || R <- Rows]}.

-spec get_heroes() -> {ok, [map()]}.
get_heroes() ->
    {ok, Rows} = query(
        "SELECT hero_id, name, network_json, fitness, origin_stable_id,
                generation, wins, losses, draws, promoted_at
         FROM heroes ORDER BY promoted_at DESC"),
    {ok, [hero_row_to_map(R) || R <- Rows]}.

-spec get_hero(binary()) -> {ok, map()} | {error, not_found}.
get_hero(HeroId) ->
    {ok, Rows} = query(
        "SELECT hero_id, name, network_json, fitness, origin_stable_id,
                generation, wins, losses, draws, promoted_at
         FROM heroes WHERE hero_id = ?1", [HeroId]),
    case Rows of
        [Row] -> {ok, hero_row_to_map(Row)};
        [] -> {error, not_found}
    end.

%%--------------------------------------------------------------------
%% gen_server callbacks
%%--------------------------------------------------------------------

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

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

step_until_done(Stmt) ->
    case esqlite3:step(Stmt) of
        '$done' -> ok;
        {row, _} -> step_until_done(Stmt);
        ok -> ok;
        {error, Code} ->
            logger:error("[query_snake_gladiators_store] SQLite step error: ~p", [Code]),
            {error, Code}
    end.

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS stables (
            stable_id TEXT PRIMARY KEY,
            status TEXT NOT NULL DEFAULT 'training',
            population_size INTEGER NOT NULL,
            max_generations INTEGER NOT NULL,
            opponent_af INTEGER NOT NULL DEFAULT 50,
            episodes_per_eval INTEGER NOT NULL DEFAULT 3,
            best_fitness REAL NOT NULL DEFAULT 0.0,
            generations_completed INTEGER NOT NULL DEFAULT 0,
            started_at INTEGER NOT NULL,
            completed_at INTEGER,
            fitness_weights TEXT
        );",
        "CREATE TABLE IF NOT EXISTS champions (
            stable_id TEXT PRIMARY KEY,
            network_json TEXT NOT NULL,
            fitness REAL NOT NULL,
            generation INTEGER NOT NULL,
            wins INTEGER NOT NULL DEFAULT 0,
            losses INTEGER NOT NULL DEFAULT 0,
            draws INTEGER NOT NULL DEFAULT 0,
            exported_at INTEGER NOT NULL
        );",
        "CREATE TABLE IF NOT EXISTS generation_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stable_id TEXT NOT NULL,
            generation INTEGER NOT NULL,
            best_fitness REAL NOT NULL,
            avg_fitness REAL NOT NULL,
            worst_fitness REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            UNIQUE(stable_id, generation)
        );",
        "CREATE TABLE IF NOT EXISTS heroes (
            hero_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            network_json TEXT NOT NULL,
            fitness REAL NOT NULL,
            origin_stable_id TEXT NOT NULL,
            generation INTEGER NOT NULL,
            wins INTEGER NOT NULL DEFAULT 0,
            losses INTEGER NOT NULL DEFAULT 0,
            draws INTEGER NOT NULL DEFAULT 0,
            promoted_at INTEGER NOT NULL
        );",
        "CREATE INDEX IF NOT EXISTS idx_stables_status ON stables(status);",
        "CREATE INDEX IF NOT EXISTS idx_gen_log_stable ON generation_log(stable_id);",
        "CREATE INDEX IF NOT EXISTS idx_heroes_promoted ON heroes(promoted_at DESC);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    %% Migration: add fitness_weights column if missing (existing DBs)
    migrate_add_column(Db, "stables", "fitness_weights", "TEXT"),
    ok.

migrate_add_column(Db, Table, Column, Type) ->
    Sql = "ALTER TABLE " ++ Table ++ " ADD COLUMN " ++ Column ++ " " ++ Type,
    case esqlite3:exec(Db, Sql) of
        ok -> ok;
        {error, _} -> ok  %% Column already exists
    end.

%%--------------------------------------------------------------------
%% Row mappers
%%--------------------------------------------------------------------

stable_row_to_map([StableId, Status, PopSize, MaxGen, OppAF, Episodes,
                   BestFit, GenDone, StartedAt, CompletedAt, FitnessWeightsJson]) ->
    FW = case FitnessWeightsJson of
        null -> null;
        undefined -> null;
        <<>> -> null;
        Bin when is_binary(Bin) -> json:decode(Bin);
        _ -> null
    end,
    #{stable_id => StableId,
      status => Status,
      population_size => PopSize,
      max_generations => MaxGen,
      opponent_af => OppAF,
      episodes_per_eval => Episodes,
      best_fitness => BestFit,
      generations_completed => GenDone,
      started_at => StartedAt,
      completed_at => CompletedAt,
      fitness_weights => FW}.

champion_row_to_map([StableId, NetJson, Fitness, Gen,
                     Wins, Losses, Draws, ExportedAt]) ->
    #{stable_id => StableId,
      network_json => NetJson,
      fitness => Fitness,
      generation => Gen,
      wins => Wins,
      losses => Losses,
      draws => Draws,
      exported_at => ExportedAt}.

gen_row_to_map([StableId, Gen, Best, Avg, Worst, Timestamp]) ->
    #{stable_id => StableId,
      generation => Gen,
      best_fitness => Best,
      avg_fitness => Avg,
      worst_fitness => Worst,
      timestamp => Timestamp}.

hero_row_to_map([HeroId, Name, NetJson, Fitness, OriginStableId,
                 Gen, Wins, Losses, Draws, PromotedAt]) ->
    #{hero_id => HeroId,
      name => Name,
      network_json => NetJson,
      fitness => Fitness,
      origin_stable_id => OriginStableId,
      generation => Gen,
      wins => Wins,
      losses => Losses,
      draws => Draws,
      promoted_at => PromotedAt}.
