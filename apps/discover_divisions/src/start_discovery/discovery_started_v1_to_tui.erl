-module(discovery_started_v1_to_tui).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(GROUP, discovery_started_v1).
-define(SCOPE, pg).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ok = ensure_pg_scope(),
    ok = pg:join(?SCOPE, ?GROUP, self()),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

handle_info({discovery_started_v1, Event}, State) ->
    VentureId = maps:get(<<"venture_id">>, Event, maps:get(venture_id, Event, <<"unknown">>)),
    Fact = #{
        <<"fact_type">> => <<"discovery_started_v1">>,
        <<"venture_id">> => VentureId,
        <<"data">> => Event
    },
    tui_facts_stream:broadcast(Fact),
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
