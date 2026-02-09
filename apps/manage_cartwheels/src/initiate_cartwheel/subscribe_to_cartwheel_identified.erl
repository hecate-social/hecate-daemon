%%% @doc Listener: Subscribe to cartwheel_identified facts
%%%
%%% Subscribes to BOTH:
%%% 1. pg group (internal) - for same-daemon events
%%% 2. mesh topic (external) - for remote-daemon events
%%%
%%% When a torch identifies a cartwheel, this listener receives the fact
%%% and forwards it to the policy for processing.
%%%
%%% This listener lives in the initiate_cartwheel spoke because its
%%% sole purpose is to trigger cartwheel initiation.
%%%
%%% Flow: pg/mesh FACT -> Listener -> Policy -> Command -> Aggregate
%%% @end
-module(subscribe_to_cartwheel_identified).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(PG_GROUP, cartwheel_identified_v1).
-define(PG_SCOPE, pg).
-define(MESH_TOPIC, <<"hecate.torch.cartwheel_identified">>).

-record(state, {
    mesh_subscription :: reference() | undefined
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
    %% Join pg group for internal events (same-daemon)
    ok = pg:join(?PG_SCOPE, ?PG_GROUP, self()),
    logger:info("[subscribe_to_cartwheel_identified] Joined pg group ~p", [?PG_GROUP]),

    %% Also subscribe to mesh for external events (remote-daemon)
    self() ! subscribe_mesh,

    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Handle pg message (internal, same-daemon)
handle_info({cartwheel_identified_v1, FactData}, State) ->
    logger:debug("[subscribe_to_cartwheel_identified] Received from pg"),
    on_cartwheel_identified_maybe_initiate_cartwheel:handle(FactData),
    {noreply, State};

%% Handle mesh message (external, remote-daemon)
handle_info({mesh_fact, ?MESH_TOPIC, FactData}, State) ->
    logger:debug("[subscribe_to_cartwheel_identified] Received from mesh"),
    on_cartwheel_identified_maybe_initiate_cartwheel:handle(FactData),
    {noreply, State};

handle_info(subscribe_mesh, State) ->
    SubRef = subscribe_to_mesh(?MESH_TOPIC),
    {noreply, State#state{mesh_subscription = SubRef}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{mesh_subscription = SubRef}) ->
    %% Leave pg group
    pg:leave(?PG_SCOPE, ?PG_GROUP, self()),
    %% Unsubscribe from mesh
    unsubscribe_mesh(SubRef),
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

subscribe_to_mesh(Topic) ->
    case hecate_mesh_client:subscribe(Topic, self()) of
        {ok, SubRef} ->
            logger:info("[subscribe_to_cartwheel_identified] Subscribed to mesh topic ~s", [Topic]),
            SubRef;
        {error, not_connected} ->
            %% Mesh not connected is OK - pg handles local events
            logger:debug("[subscribe_to_cartwheel_identified] Mesh not connected (pg handles local events)"),
            undefined;
        {error, Reason} ->
            logger:warning("[subscribe_to_cartwheel_identified] Failed to subscribe to mesh: ~p", [Reason]),
            undefined
    end.

unsubscribe_mesh(undefined) -> ok;
unsubscribe_mesh(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).
