%%% @doc Listener: torch_archived_v1 from pg -> sqlite torches projection
%%% Subscribes to torch_archived_v1 pg group and triggers projection.
-module(on_torch_archived_v1_from_pg_project_to_sqlite_torches).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(GROUP, torch_archived_v1).
-define(SCOPE, pg).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Ensure pg scope exists
    ok = ensure_pg_scope(),
    %% Join the pg group for torch_archived_v1 events
    ok = pg:join(?SCOPE, ?GROUP, self()),
    logger:info("[~s] Joined pg group ~p in scope ~p", [?MODULE, ?GROUP, ?SCOPE]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({torch_archived_v1, Event}, State) ->
    logger:info("[~s] Received torch_archived_v1 event", [?MODULE]),
    %% Call the projection
    Result = torch_archived_v1_to_sqlite_torches:project(Event),
    case Result of
        ok ->
            logger:info("[~s] Projection succeeded", [?MODULE]);
        {error, Reason} ->
            logger:error("[~s] Projection failed: ~p", [?MODULE, Reason])
    end,
    {noreply, State};

handle_info(Info, State) ->
    logger:warning("[~s] Unexpected info: ~p", [?MODULE, Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% Internal

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
