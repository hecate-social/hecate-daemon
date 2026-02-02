%%% @doc SQLite store for subscription read models
-module(query_subscriptions_store).
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
    DbPath = filename:join([DataDir, "query_subscriptions.db"]),
    filelib:ensure_dir(DbPath),

    {ok, Db} = esqlite3:open(DbPath),
    {ok, #state{db = Db}}.

handle_call(init_schema, _From, State) ->
    %% === LOCAL TABLES (from MY domain events) ===

    %% Topics I subscribe to (from my subscribed_v1 events)
    LocalSchemas = [
        <<"CREATE TABLE IF NOT EXISTS subscriptions (
            agent_identity TEXT NOT NULL,
            topic TEXT NOT NULL,
            filter TEXT,
            subscribed_at INTEGER NOT NULL,
            active INTEGER DEFAULT 1,
            PRIMARY KEY (agent_identity, topic)
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_subscriptions_agent
           ON subscriptions(agent_identity)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_subscriptions_topic
           ON subscriptions(topic)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_subscriptions_active
           ON subscriptions(active)">>
    ],

    %% === REMOTE TABLES (from mesh facts about ME) ===

    %% Subscribers TO my services/topics (from filtered mesh facts: subscription.subscribed where owner ∈ MY_IDENTITIES)
    RemoteSchemas = [
        <<"CREATE TABLE IF NOT EXISTS my_subscribers (
            subscriber_identity TEXT NOT NULL,
            my_identity TEXT NOT NULL,
            topic TEXT NOT NULL,
            filter TEXT,
            subscribed_at INTEGER NOT NULL,
            active INTEGER DEFAULT 1,
            discovered_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            PRIMARY KEY (subscriber_identity, my_identity, topic)
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_subscribers_identity
           ON my_subscribers(my_identity)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_subscribers_topic
           ON my_subscribers(topic)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_subscribers_active
           ON my_subscribers(active)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_subscribers_subscribed_at
           ON my_subscribers(subscribed_at DESC)">>
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
