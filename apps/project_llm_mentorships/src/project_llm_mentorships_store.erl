%%% @doc Hybrid store for LLM mentorship read models.
%%% ETS tables: learnings, mentor_subscriptions, mentor_profiles (for evoq_projection)
%%% SQLite tables: remote_learnings, remote_mentors (for mesh listeners)
-module(project_llm_mentorships_store).
-behaviour(gen_server).

-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% SQLite access (for mesh listener tables only)
-export([execute/2, query/2]).

%% ETS query facade: learnings
-export([get_learning/1, list_learnings/1]).

%% ETS query facade: mentor_profiles
-export([get_mentor_profile/1, list_mentor_profiles/0, list_mentor_profiles/1]).

%% ETS query facade: mentor_subscriptions
-export([get_subscriptions_for/1]).

-record(state, {db :: reference()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% ETS tables for evoq_projection read models
    ets:new(learnings, [public, named_table, set, {read_concurrency, true}]),
    ets:new(mentor_subscriptions, [public, named_table, set, {read_concurrency, true}]),
    ets:new(mentor_profiles, [public, named_table, set, {read_concurrency, true}]),

    %% SQLite for mesh listener tables (remote_learnings, remote_mentors)
    DbPath = shared_paths:sqlite_path("query_mentorships.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    ok = create_remote_tables(Db),
    {ok, #state{db = Db}}.

%%====================================================================
%% ETS Query Facade: learnings
%%====================================================================

-spec get_learning(binary()) -> {ok, map()} | {error, not_found}.
get_learning(LearningId) ->
    case ets:lookup(learnings, LearningId) of
        [{_, Learning}] -> {ok, Learning};
        [] -> {error, not_found}
    end.

-spec list_learnings(map()) -> {ok, [map()]}.
list_learnings(Filters) ->
    All = [V || {_, V} <- ets:tab2list(learnings)],
    Filtered = apply_learning_filters(All, Filters),
    Sorted = lists:sort(fun(A, B) ->
        maps:get(submitted_at, A, 0) >= maps:get(submitted_at, B, 0)
    end, Filtered),
    Offset = maps:get(offset, Filters, 0),
    Limit = maps:get(limit, Filters, 50),
    Page = lists:sublist(safe_nthtail(Offset, Sorted), Limit),
    {ok, Page}.

%%====================================================================
%% ETS Query Facade: mentor_profiles
%%====================================================================

-spec get_mentor_profile(binary()) -> {ok, map()} | {error, not_found}.
get_mentor_profile(AgentId) ->
    case ets:lookup(mentor_profiles, AgentId) of
        [{_, Profile}] -> {ok, Profile};
        [] -> {error, not_found}
    end.

-spec list_mentor_profiles() -> {ok, [map()]}.
list_mentor_profiles() ->
    list_mentor_profiles(#{}).

-spec list_mentor_profiles(map()) -> {ok, [map()]}.
list_mentor_profiles(Filters) ->
    All = [V || {_, V} <- ets:tab2list(mentor_profiles)],
    %% Only active profiles (status & 1 != 0)
    Active = [P || P <- All, maps:get(status, P, 0) band 1 =/= 0],
    Filtered = case maps:get(domain, Filters, undefined) of
        undefined -> Active;
        Domain ->
            [P || P <- Active,
             lists:member(Domain, maps:get(domains, P, []))]
    end,
    {ok, Filtered}.

%%====================================================================
%% ETS Query Facade: mentor_subscriptions
%%====================================================================

-spec get_subscriptions_for(binary()) -> {ok, [map()]}.
get_subscriptions_for(SubscriberId) ->
    All = [V || {_, V} <- ets:tab2list(mentor_subscriptions)],
    Active = [S || S <- All,
              maps:get(subscriber_id, S) =:= SubscriberId,
              maps:get(status, S, 0) band 1 =/= 0],
    {ok, Active}.

%%====================================================================
%% SQLite access (for mesh listener remote tables)
%%====================================================================

-spec execute(iodata(), [term()]) -> ok | {error, term()}.
execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

-spec query(iodata(), [term()]) -> {ok, [list()]} | {error, term()}.
query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

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

%%====================================================================
%% Internal
%%====================================================================

step_until_done(Stmt) ->
    case esqlite3:step(Stmt) of
        '$done' -> ok;
        {row, _} -> step_until_done(Stmt);
        ok -> ok
    end.

apply_learning_filters(Learnings, Filters) ->
    lists:filter(fun(L) ->
        match_field(domain, Filters, L) andalso
        match_field(category, Filters, L) andalso
        match_field(submitter_id, Filters, L) andalso
        match_status_mask(Filters, L)
    end, Learnings).

match_field(Key, Filters, Learning) ->
    case maps:get(Key, Filters, undefined) of
        undefined -> true;
        Value -> maps:get(Key, Learning, undefined) =:= Value
    end.

match_status_mask(Filters, Learning) ->
    case maps:get(status_mask, Filters, undefined) of
        undefined -> true;
        Mask -> maps:get(status, Learning, 0) band Mask =/= 0
    end.

safe_nthtail(0, List) -> List;
safe_nthtail(_, []) -> [];
safe_nthtail(N, [_ | T]) -> safe_nthtail(N - 1, T).

create_remote_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS remote_learnings (
            id TEXT PRIMARY KEY,
            source_agent TEXT NOT NULL,
            category TEXT,
            domain TEXT,
            title TEXT,
            learning_data TEXT,
            discovered_at INTEGER,
            applied INTEGER DEFAULT 0
        );",
        "CREATE INDEX IF NOT EXISTS idx_remote_learnings_domain ON remote_learnings(domain);",

        "CREATE TABLE IF NOT EXISTS remote_mentors (
            agent_id TEXT PRIMARY KEY,
            domains TEXT,
            discovered_at INTEGER,
            last_seen_at INTEGER
        );"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
