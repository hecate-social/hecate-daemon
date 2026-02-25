%%% @doc Listener: subscribes to license_initiated_v1 via evoq,
%%% calls projection to insert into catalog.
-module(on_license_initiated_v1_to_sqlite_catalog).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-define(EVENT_TYPE, <<"license_initiated_v1">>).
-define(SUB_NAME, <<"license_initiated_v1_to_catalog">>).
-define(STORE_ID, licenses_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(E) ->
        Map = projection_event:to_map(E),
        license_initiated_v1_to_sqlite_catalog:project(Map)
    end, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
