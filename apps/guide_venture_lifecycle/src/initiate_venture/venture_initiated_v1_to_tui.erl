%%% @doc Emitter: venture_initiated_v1 -> TUI SSE connections
%%% Subscribes to dev_studio_store via evoq, broadcasts facts to TUI clients via pg.
-module(venture_initiated_v1_to_tui).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"venture_initiated_v1">>).
-define(SUB_NAME, <<"venture_initiated_v1_to_tui">>).
-define(STORE_ID, dev_studio_store).
-define(SCOPE, pg).
-define(TUI_GROUP, tui_connections).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    Members = pg:get_members(?SCOPE, ?TUI_GROUP),
    case Members of
        [] ->
            ok;
        _ ->
            lists:foreach(fun(E) ->
                Data = iolist_to_binary(json:encode(#{
                    <<"fact_type">> => ?EVENT_TYPE,
                    <<"data">> => E
                })),
                lists:foreach(fun(Pid) -> Pid ! {tui_fact, Data} end, Members)
            end, Events)
    end,
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
