%%% @doc Listener: subscribes to pg group for release_deployed_v1 events.
-module(on_release_deployed_v1_from_pg_project_to_sqlite_releases).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(GROUP, release_deployed_v1).
-define(SCOPE, pg).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ok = ensure_pg_scope(),
    ok = pg:join(?SCOPE, ?GROUP, self()),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

handle_info({release_deployed_v1, Event}, State) ->
    case release_deployed_v1_to_sqlite_releases:project(Event) of
        ok -> ok;
        {error, Reason} ->
            logger:warning("[release_deployed_v1 projection] failed: ~p", [Reason])
    end,
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
