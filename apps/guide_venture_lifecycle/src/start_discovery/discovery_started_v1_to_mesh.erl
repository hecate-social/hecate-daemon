%%% @doc Mesh emitter: discovery_started_v1 -> Macula Mesh
%%%
%%% Publishes discovery started facts to mesh topic hecate.venture.discovery.started.
%%% @end
-module(discovery_started_v1_to_mesh).
-behaviour(gen_server).

-export([start_link/0, emit/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TOPIC, <<"hecate.venture.discovery.started">>).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Emit a discovery started fact to the mesh.
-spec emit(map()) -> ok.
emit(EventData) ->
    gen_server:cast(?MODULE, {emit, EventData}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    logger:info("[discovery_started_v1_to_mesh] Emitter started"),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({emit, EventData}, State) ->
    VentureId = maps:get(<<"venture_id">>, EventData, maps:get(venture_id, EventData, <<"unknown">>)),
    case hecate_mesh_client:publish(?TOPIC, EventData) of
        ok ->
            logger:info("[discovery_started_v1_to_mesh] Published for venture ~s to mesh", [VentureId]);
        {error, not_connected} ->
            logger:warning("[discovery_started_v1_to_mesh] Mesh not connected, fact not published");
        {error, Reason} ->
            logger:error("[discovery_started_v1_to_mesh] Failed to publish: ~p", [Reason])
    end,
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
