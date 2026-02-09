%%% @doc TUI emitter: torch_initiated_v1 → TUI SSE connections
%%%
%%% Listens to the torch_initiated_v1 pg group (same as projections)
%%% and broadcasts JSON-encoded facts to all connected TUI clients.
%%%
%%% Each _to_tui emitter does its own encoding and broadcasting,
%%% following the same self-contained pattern as _to_pg and _to_mesh.
%%% @end
-module(torch_initiated_v1_to_tui).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SCOPE, pg).
-define(EVENT_GROUP, torch_initiated_v1).
-define(TUI_GROUP, tui_connections).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ok = ensure_pg_scope(),
    ok = pg:join(?SCOPE, ?EVENT_GROUP, self()),
    logger:info("[torch_initiated_v1_to_tui] Emitter started, joined ~p group", [?EVENT_GROUP]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({torch_initiated_v1, Event}, State) ->
    Members = pg:get_members(?SCOPE, ?TUI_GROUP),
    case Members of
        [] ->
            ok;
        _ ->
            Data = iolist_to_binary(json:encode(#{
                <<"fact_type">> => <<"torch_initiated_v1">>,
                <<"data">> => Event
            })),
            lists:foreach(fun(Pid) -> Pid ! {tui_fact, Data} end, Members),
            TorchId = maps:get(<<"torch_id">>, Event, maps:get(torch_id, Event, <<"unknown">>)),
            logger:info("[torch_initiated_v1_to_tui] Broadcast to ~b TUI client(s), torch=~s",
                        [length(Members), TorchId])
    end,
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
