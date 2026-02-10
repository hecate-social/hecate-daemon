-module(on_discovery_facts_from_pg).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SCOPE, pg).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ok = ensure_pg_scope(),
    ok = pg:join(?SCOPE, discovery_started_v1, self()),
    ok = pg:join(?SCOPE, division_discovered_v1, self()),
    ok = pg:join(?SCOPE, discovery_completed_v1, self()),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

handle_info({discovery_started_v1, Event}, State) ->
    VentureId = maps:get(venture_id, Event, maps:get(<<"venture_id">>, Event, undefined)),
    venture_state:record_discovery_started(VentureId),
    {noreply, State};

handle_info({division_discovered_v1, Event}, State) ->
    VentureId = maps:get(venture_id, Event, maps:get(<<"venture_id">>, Event, undefined)),
    DivisionId = maps:get(division_id, Event, maps:get(<<"division_id">>, Event, undefined)),
    Name = maps:get(name, Event, maps:get(<<"name">>, Event, <<>>)),
    venture_state:record_division_discovered(VentureId, DivisionId, Name),
    {noreply, State};

handle_info({discovery_completed_v1, Event}, State) ->
    VentureId = maps:get(venture_id, Event, maps:get(<<"venture_id">>, Event, undefined)),
    venture_state:record_discovery_completed(VentureId),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
