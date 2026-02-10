%%% @doc Listener: subscribes to pg groups for lifecycle events (paused/resumed/completed).
-module(on_plan_lifecycle_from_pg_project_to_sqlite_plans).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SCOPE, pg).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ok = ensure_pg_scope(),
    ok = pg:join(?SCOPE, plan_paused_v1, self()),
    ok = pg:join(?SCOPE, plan_resumed_v1, self()),
    ok = pg:join(?SCOPE, plan_completed_v1, self()),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

handle_info({plan_paused_v1, Event}, State) ->
    safe_project(fun() -> plan_lifecycle_to_sqlite_plans:project_paused(Event) end,
                 plan_paused_v1),
    {noreply, State};
handle_info({plan_resumed_v1, Event}, State) ->
    safe_project(fun() -> plan_lifecycle_to_sqlite_plans:project_resumed(Event) end,
                 plan_resumed_v1),
    {noreply, State};
handle_info({plan_completed_v1, Event}, State) ->
    safe_project(fun() -> plan_lifecycle_to_sqlite_plans:project_completed(Event) end,
                 plan_completed_v1),
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

safe_project(Fun, EventType) ->
    case Fun() of
        ok -> ok;
        {error, Reason} ->
            logger:warning("[~s projection] failed: ~p", [EventType, Reason])
    end.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
