%%% @doc Emitter: Publish cartwheel_identified_v1 events to mesh
%%%
%%% When a cartwheel is identified within a torch, this emitter publishes
%%% the fact to mesh topic `hecate.torch.cartwheel_identified`.
%%%
%%% The manage_cartwheels service subscribes to this topic and initiates
%%% the cartwheel's lifecycle.
%%%
%%% Flow: cartwheel_identified_v1 (event) -> emitter -> mesh fact
%%% @end
-module(cartwheel_identified_v1_to_mesh).
-behaviour(gen_server).

-export([start_link/0, emit/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TOPIC, <<"hecate.torch.cartwheel_identified">>).

-record(state, {}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Emit a cartwheel_identified event to mesh
-spec emit(map() | cartwheel_identified_v1:cartwheel_identified_v1()) -> ok.
emit(Event) when is_map(Event) ->
    gen_server:cast(?MODULE, {emit, Event});
emit(Event) ->
    gen_server:cast(?MODULE, {emit, cartwheel_identified_v1:to_map(Event)}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    logger:info("[cartwheel_identified_v1_to_mesh] Starting emitter for topic ~s", [?TOPIC]),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({emit, EventData}, State) ->
    do_emit(EventData),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

do_emit(EventData) ->
    TorchId = maps:get(<<"torch_id">>, EventData, maps:get(torch_id, EventData, undefined)),
    CartwheelId = maps:get(<<"cartwheel_id">>, EventData, maps:get(cartwheel_id, EventData, undefined)),
    ContextName = maps:get(<<"context_name">>, EventData, maps:get(context_name, EventData, undefined)),

    logger:debug("[cartwheel_identified_v1_to_mesh] Emitting cartwheel ~s (~s) for torch ~s",
                [CartwheelId, ContextName, TorchId]),

    %% Publish to mesh
    case hecate_mesh_client:publish(?TOPIC, EventData) of
        ok ->
            logger:info("[cartwheel_identified_v1_to_mesh] Published to ~s: torch=~s cartwheel=~s",
                       [?TOPIC, TorchId, CartwheelId]);
        {error, not_connected} ->
            logger:warning("[cartwheel_identified_v1_to_mesh] Mesh not connected, fact not published");
        {error, Reason} ->
            logger:error("[cartwheel_identified_v1_to_mesh] Failed to publish: ~p", [Reason])
    end.
