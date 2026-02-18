%%%-------------------------------------------------------------------
%%% @doc Hecate SQLite store.
%%%
%%% Provides persistent storage for:
%%% - Identity (MRI, keypair)
%%% - Events (audit log)
%%% - UCAN capabilities
%%% - Configuration
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_store).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([
    get/2,
    put/3,
    delete/2,
    list/1,
    append_event/3,
    get_events/2
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).

-record(state, {
    db :: esqlite3:esqlite3()
}).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec get(Bucket :: binary(), Key :: binary()) -> {ok, term()} | not_found.
get(Bucket, Key) ->
    gen_server:call(?SERVER, {get, Bucket, Key}).

-spec put(Bucket :: binary(), Key :: binary(), Value :: term()) -> ok.
put(Bucket, Key, Value) ->
    gen_server:call(?SERVER, {put, Bucket, Key, Value}).

-spec delete(Bucket :: binary(), Key :: binary()) -> ok.
delete(Bucket, Key) ->
    gen_server:call(?SERVER, {delete, Bucket, Key}).

-spec list(Bucket :: binary()) -> [{binary(), term()}].
list(Bucket) ->
    gen_server:call(?SERVER, {list, Bucket}).

-spec append_event(Stream :: binary(), Type :: binary(), Data :: term()) -> ok.
append_event(Stream, Type, Data) ->
    gen_server:call(?SERVER, {append_event, Stream, Type, Data}).

-spec get_events(Stream :: binary(), Opts :: map()) -> [map()].
get_events(Stream, Opts) ->
    gen_server:call(?SERVER, {get_events, Stream, Opts}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    DbPath = shared_paths:sqlite_path("hecate.db"),
    ok = filelib:ensure_dir(DbPath),

    logger:info("Opening store at ~s", [DbPath]),
    {ok, Db} = esqlite3:open(DbPath),
    
    ok = init_schema(Db),
    
    {ok, #state{db = Db}}.

handle_call({get, Bucket, Key}, _From, #state{db = Db} = State) ->
    Sql = "SELECT value FROM kv WHERE bucket = ?1 AND key = ?2",
    Result = case esqlite3:q(Db, Sql, [Bucket, Key]) of
        [[Value]] -> {ok, binary_to_term(Value)};
        [] -> not_found
    end,
    {reply, Result, State};

handle_call({put, Bucket, Key, Value}, _From, #state{db = Db} = State) ->
    Sql = "INSERT OR REPLACE INTO kv (bucket, key, value, updated_at) VALUES (?1, ?2, ?3, ?4)",
    ValueBin = term_to_binary(Value),
    Now = erlang:system_time(second),
    [] = esqlite3:q(Db, Sql, [Bucket, Key, ValueBin, Now]),
    {reply, ok, State};

handle_call({delete, Bucket, Key}, _From, #state{db = Db} = State) ->
    Sql = "DELETE FROM kv WHERE bucket = ?1 AND key = ?2",
    [] = esqlite3:q(Db, Sql, [Bucket, Key]),
    {reply, ok, State};

handle_call({list, Bucket}, _From, #state{db = Db} = State) ->
    Sql = "SELECT key, value FROM kv WHERE bucket = ?1",
    Rows = esqlite3:q(Db, Sql, [Bucket]),
    Result = [{K, binary_to_term(V)} || [K, V] <- Rows],
    {reply, Result, State};

handle_call({append_event, Stream, Type, Data}, _From, #state{db = Db} = State) ->
    Sql = "INSERT INTO events (stream_id, type, data, created_at) VALUES (?1, ?2, ?3, ?4)",
    DataBin = term_to_binary(Data),
    Now = erlang:system_time(second),
    [] = esqlite3:q(Db, Sql, [Stream, Type, DataBin, Now]),
    {reply, ok, State};

handle_call({get_events, Stream, Opts}, _From, #state{db = Db} = State) ->
    Limit = maps:get(limit, Opts, 100),
    Sql = "SELECT id, type, data, created_at FROM events WHERE stream_id = ?1 ORDER BY id DESC LIMIT ?2",
    Rows = esqlite3:q(Db, Sql, [Stream, Limit]),
    Events = [#{
        id => Id,
        type => Type,
        data => binary_to_term(Data),
        created_at => CreatedAt
    } || [Id, Type, Data, CreatedAt] <- Rows],
    {reply, lists:reverse(Events), State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{db = Db}) ->
    esqlite3:close(Db),
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

init_schema(Db) ->
    %% Key-value store
    ok = esqlite3:exec(Db,
        "CREATE TABLE IF NOT EXISTS kv (
            bucket TEXT NOT NULL,
            key TEXT NOT NULL,
            value BLOB NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (bucket, key)
        )"),
    
    %% Event log
    ok = esqlite3:exec(Db,
        "CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stream_id TEXT NOT NULL,
            type TEXT NOT NULL,
            data BLOB NOT NULL,
            created_at INTEGER NOT NULL
        )"),
    
    ok = esqlite3:exec(Db,
        "CREATE INDEX IF NOT EXISTS idx_events_stream ON events (stream_id, id)"),
    
    ok.
