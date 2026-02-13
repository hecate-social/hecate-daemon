%%% @doc Emitter: discovery_completed_v1 -> pg (internal pub/sub)
%%% Subscribes to dev_studio_store via evoq, broadcasts to pg group.
-module(discovery_completed_v1_to_pg).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"discovery_completed_v1">>).
-define(PG_GROUP, discovery_completed_v1).
-define(SUB_NAME, <<"discovery_completed_v1_to_pg">>).
-define(STORE_ID, dev_studio_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    Members = pg:get_members(pg, ?PG_GROUP),
    lists:foreach(fun(E) ->
        Msg = {?PG_GROUP, E},
        lists:foreach(fun(Pid) -> Pid ! Msg end, Members)
    end, Events),
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
