%%% @doc Emitter: event_sticky_pulled_v1 -> Macula Mesh
%%% Subscribes to dev_studio_store via evoq, publishes facts to mesh topic.
-module(event_sticky_pulled_v1_to_mesh).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"event_sticky_pulled_v1">>).
-define(TOPIC, <<"hecate.venture.storm.sticky.pulled">>).
-define(SUB_NAME, <<"event_sticky_pulled_v1_to_mesh">>).
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
        case hecate_mesh_client:publish(?TOPIC, E) of
            ok -> ok;
            {error, not_connected} -> ok;
            {error, Reason} ->
                logger:warning("[~s] Mesh publish failed: ~p", [?MODULE, Reason])
        end
    end, Events),
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
