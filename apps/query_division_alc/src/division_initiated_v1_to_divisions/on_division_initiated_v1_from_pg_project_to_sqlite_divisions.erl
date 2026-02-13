%%% @doc Listener: subscribes to event store for division_initiated_v1 events.
-module(on_division_initiated_v1_from_pg_project_to_sqlite_divisions).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"division_initiated_v1">>).
-define(SUB_NAME, <<"division_initiated_v1_to_sqlite_divisions">>).
-define(STORE_ID, dev_studio_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(E) ->
        case division_initiated_v1_to_sqlite_divisions:project(E) of
            ok -> ok;
            {error, Reason} ->
                logger:warning("[~s] projection failed: ~p", [?EVENT_TYPE, Reason])
        end
    end, Events),
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
