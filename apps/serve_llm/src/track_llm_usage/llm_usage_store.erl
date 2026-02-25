%%% @doc SQLite storage for LLM usage and cost tracking.
%%% @end
-module(llm_usage_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([record_llm_call/1]).
-export([get_cost_by_venture/1, get_cost_by_division/1, get_cost_by_agent/1, get_total_cost/0]).
-export([list_calls_by_venture/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    db :: term()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec record_llm_call(map()) -> ok | {error, term()}.
record_llm_call(Data) when is_map(Data) ->
    gen_server:call(?MODULE, {record_llm_call, Data}).

-spec get_cost_by_venture(binary()) -> {ok, float()} | {error, term()}.
get_cost_by_venture(VentureId) ->
    gen_server:call(?MODULE, {get_cost_by_venture, VentureId}).

-spec get_cost_by_division(binary()) -> {ok, float()} | {error, term()}.
get_cost_by_division(DivisionId) ->
    gen_server:call(?MODULE, {get_cost_by_division, DivisionId}).

-spec get_cost_by_agent(binary()) -> {ok, float()} | {error, term()}.
get_cost_by_agent(AgentId) ->
    gen_server:call(?MODULE, {get_cost_by_agent, AgentId}).

-spec get_total_cost() -> {ok, float()} | {error, term()}.
get_total_cost() ->
    gen_server:call(?MODULE, get_total_cost).

-spec list_calls_by_venture(binary(), map()) -> {ok, [map()]} | {error, term()}.
list_calls_by_venture(VentureId, Opts) ->
    gen_server:call(?MODULE, {list_calls_by_venture, VentureId, Opts}).

%%% gen_server callbacks

init([]) ->
    DbPath = shared_paths:sqlite_path("llm_usage.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    init_schema(Db),
    {ok, #state{db = Db}}.

handle_call({record_llm_call, Data}, _From, #state{db = Db} = State) ->
    VentureId = maps:get(venture_id, Data, <<"default">>),
    DivisionId = maps:get(division_id, Data, null),
    AgentId = maps:get(agent_id, Data, null),
    TaskId = maps:get(task_id, Data, null),
    Model = maps:get(model, Data),
    TokensIn = maps:get(tokens_in, Data),
    TokensOut = maps:get(tokens_out, Data),
    CostUsd = maps:get(cost_usd, Data, null),
    Timestamp = erlang:system_time(millisecond),

    Sql = <<"INSERT INTO llm_calls (venture_id, division_id, agent_id, task_id, model, tokens_in, tokens_out, cost_usd, timestamp)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)">>,
    Params = [VentureId, DivisionId, AgentId, TaskId, Model, TokensIn, TokensOut, CostUsd, Timestamp],

    case esqlite3:q(Db, Sql, Params) of
        Rows when is_list(Rows) -> {reply, ok, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end;

handle_call({get_cost_by_venture, VentureId}, _From, #state{db = Db} = State) ->
    {reply, do_get_cost_by_field(Db, <<"venture_id">>, VentureId), State};

handle_call({get_cost_by_division, DivisionId}, _From, #state{db = Db} = State) ->
    {reply, do_get_cost_by_field(Db, <<"division_id">>, DivisionId), State};

handle_call({get_cost_by_agent, AgentId}, _From, #state{db = Db} = State) ->
    {reply, do_get_cost_by_field(Db, <<"agent_id">>, AgentId), State};

handle_call(get_total_cost, _From, #state{db = Db} = State) ->
    Sql = <<"SELECT COALESCE(SUM(cost_usd), 0.0) FROM llm_calls">>,
    Result = case esqlite3:q(Db, Sql, []) of
        [[Cost]] when is_number(Cost) -> {ok, Cost};
        [[undefined]] -> {ok, 0.0};
        [] -> {ok, 0.0};
        {error, Reason} -> {error, Reason}
    end,
    {reply, Result, State};

handle_call({list_calls_by_venture, VentureId, Opts}, _From, #state{db = Db} = State) ->
    Limit = maps:get(limit, Opts, 100),
    Offset = maps:get(offset, Opts, 0),
    Sql = <<"SELECT id, venture_id, division_id, agent_id, task_id, model, tokens_in, tokens_out, cost_usd, timestamp
            FROM llm_calls WHERE venture_id = ?1 ORDER BY timestamp DESC LIMIT ?2 OFFSET ?3">>,
    Result = case esqlite3:q(Db, Sql, [VentureId, Limit, Offset]) of
        Rows when is_list(Rows) -> {ok, lists:map(fun row_to_map/1, Rows)};
        {error, Reason} -> {error, Reason}
    end,
    {reply, Result, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{db = Db}) ->
    esqlite3:close(Db),
    ok.

%%% Internal

init_schema(Db) ->
    Schemas = [
        <<"CREATE TABLE IF NOT EXISTS llm_calls (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            venture_id TEXT NOT NULL,
            division_id TEXT,
            agent_id TEXT,
            task_id TEXT,
            model TEXT NOT NULL,
            tokens_in INTEGER NOT NULL,
            tokens_out INTEGER NOT NULL,
            cost_usd REAL,
            timestamp INTEGER NOT NULL
        )">>,
        <<"CREATE INDEX IF NOT EXISTS idx_llm_calls_venture ON llm_calls(venture_id, timestamp)">>,
        <<"CREATE INDEX IF NOT EXISTS idx_llm_calls_division ON llm_calls(division_id, timestamp)">>,
        <<"CREATE INDEX IF NOT EXISTS idx_llm_calls_agent ON llm_calls(agent_id, timestamp)">>
    ],
    [esqlite3:exec(Db, Sql) || Sql <- Schemas],
    ok.

do_get_cost_by_field(Db, Field, Value) ->
    Sql = iolist_to_binary([
        <<"SELECT COALESCE(SUM(cost_usd), 0.0) FROM llm_calls WHERE ">>,
        Field, <<" = ?1">>
    ]),
    case esqlite3:q(Db, Sql, [Value]) of
        [[Cost]] when is_number(Cost) -> {ok, Cost};
        [[undefined]] -> {ok, 0.0};
        [] -> {ok, 0.0};
        {error, Reason} -> {error, Reason}
    end.

row_to_map([Id, VentureId, DivisionId, AgentId, TaskId, Model, TokensIn, TokensOut, CostUsd, Timestamp]) ->
    #{
        id => Id, venture_id => VentureId, division_id => DivisionId,
        agent_id => AgentId, task_id => TaskId, model => Model,
        tokens_in => TokensIn, tokens_out => TokensOut,
        cost_usd => CostUsd, timestamp => Timestamp
    }.
