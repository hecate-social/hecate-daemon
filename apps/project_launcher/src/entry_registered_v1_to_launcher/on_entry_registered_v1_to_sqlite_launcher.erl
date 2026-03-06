%%% @doc Listener for entry_registered_v1 events.
%%% Subscribes to evoq, projects to SQLite launcher tables.
-module(on_entry_registered_v1_to_sqlite_launcher).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-include_lib("evoq/include/evoq_types.hrl").

-define(EVENT_TYPE, <<"entry_registered_v1">>).
-define(SUB_NAME, <<"entry_registered_v1_to_sqlite_launcher">>).
-define(STORE_ID, launcher_store).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = evoq_subscriptions:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(#evoq_event{data = Data}) ->
        case entry_registered_v1_to_sqlite_launcher:project(Data) of
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
