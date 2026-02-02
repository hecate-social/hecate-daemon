%%% @doc SQLite store for social graph read models
-module(query_social_store).
-behaviour(gen_server).

-export([start_link/0, init_schema/0, execute/1, query/1, query/2]).
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
    gen_server:call(?MODULE, {query, Sql, []}).

query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

%% Callbacks

init([]) ->
    DataDir = application:get_env(hecate, data_dir, "~/.hecate"),
    DbPath = filename:join([DataDir, "query_social.db"]),
    filelib:ensure_dir(DbPath),

    {ok, Db} = esqlite3:open(DbPath),
    {ok, #state{db = Db}}.

handle_call(init_schema, _From, State) ->
    %% === LOCAL TABLES (from MY domain events) ===

    %% People I follow (from my agent_followed_v1 events)
    LocalSchemas = [
        <<"CREATE TABLE IF NOT EXISTS followers (
            follower_identity TEXT NOT NULL,
            followed_identity TEXT NOT NULL,
            followed_at INTEGER NOT NULL,
            PRIMARY KEY (follower_identity, followed_identity)
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_followers_follower
           ON followers(follower_identity)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_followers_followed
           ON followers(followed_identity)">>,

        %% Endorsements I made (from my capability_endorsed_v1 events)
        <<"CREATE TABLE IF NOT EXISTS endorsements (
            endorser_identity TEXT NOT NULL,
            capability_mri TEXT NOT NULL,
            comment TEXT,
            endorsed_at INTEGER NOT NULL,
            revoked_at INTEGER,
            PRIMARY KEY (endorser_identity, capability_mri)
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_endorsements_endorser
           ON endorsements(endorser_identity)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_endorsements_capability
           ON endorsements(capability_mri)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_endorsements_active
           ON endorsements(capability_mri) WHERE revoked_at IS NULL">>
    ],

    %% === REMOTE TABLES (from mesh facts about ME) ===

    %% People who follow ME (from filtered mesh facts: social.followed where target ∈ MY_IDENTITIES)
    RemoteSchemas = [
        <<"CREATE TABLE IF NOT EXISTS my_followers (
            follower_identity TEXT NOT NULL,
            my_identity TEXT NOT NULL,
            followed_at INTEGER NOT NULL,
            discovered_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            PRIMARY KEY (follower_identity, my_identity)
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_followers_identity
           ON my_followers(my_identity)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_followers_followed_at
           ON my_followers(followed_at DESC)">>,

        %% Endorsements OF my capabilities (from filtered mesh facts: social.endorsed where owner ∈ MY_IDENTITIES)
        <<"CREATE TABLE IF NOT EXISTS my_endorsements (
            endorser_identity TEXT NOT NULL,
            my_capability_mri TEXT NOT NULL,
            comment TEXT,
            endorsed_at INTEGER NOT NULL,
            revoked_at INTEGER,
            discovered_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            PRIMARY KEY (endorser_identity, my_capability_mri)
        )">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_endorsements_capability
           ON my_endorsements(my_capability_mri)">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_endorsements_active
           ON my_endorsements(my_capability_mri) WHERE revoked_at IS NULL">>,

        <<"CREATE INDEX IF NOT EXISTS idx_my_endorsements_endorsed_at
           ON my_endorsements(endorsed_at DESC)">>
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

handle_call({query, Sql, Params}, _From, State) ->
    %% esqlite3:q returns [[col1, col2,...], ...] or {error, Reason}
    %% Wrap in {ok, Rows} for consistency
    case esqlite3:q(State#state.db, Sql, Params) of
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
