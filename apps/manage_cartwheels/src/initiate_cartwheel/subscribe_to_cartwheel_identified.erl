%%% @doc Listener: Subscribe to cartwheel_identified facts from mesh
%%%
%%% Subscribes to mesh topic `hecate.torch.cartwheel_identified`.
%%% When a torch identifies a cartwheel, this listener receives the fact
%%% and forwards it to the policy for processing.
%%%
%%% This listener lives in the initiate_cartwheel spoke because its
%%% sole purpose is to trigger cartwheel initiation.
%%%
%%% Flow: Mesh FACT -> Listener -> Policy -> Command -> Aggregate
%%% @end
-module(subscribe_to_cartwheel_identified).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TOPIC, <<"hecate.torch.cartwheel_identified">>).

-record(state, {
    subscription :: reference() | undefined
}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    self() ! subscribe,
    logger:info("[subscribe_to_cartwheel_identified] Starting listener for topic ~s", [?TOPIC]),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    SubRef = subscribe_to_topic(?TOPIC),
    {noreply, State#state{subscription = SubRef}};

handle_info({mesh_fact, ?TOPIC, FactData}, State) ->
    %% Forward to policy for processing
    on_cartwheel_identified_maybe_initiate_cartwheel:handle(FactData),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription = SubRef}) ->
    unsubscribe(SubRef),
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

subscribe_to_topic(Topic) ->
    case hecate_mesh_client:subscribe(Topic, self()) of
        {ok, SubRef} ->
            logger:info("[subscribe_to_cartwheel_identified] Subscribed to ~s", [Topic]),
            SubRef;
        {error, not_connected} ->
            %% Retry subscription in 5 seconds
            logger:warning("[subscribe_to_cartwheel_identified] Mesh not connected, retrying in 5s"),
            erlang:send_after(5000, self(), subscribe),
            undefined;
        {error, Reason} ->
            logger:error("[subscribe_to_cartwheel_identified] Failed to subscribe: ~p", [Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).
