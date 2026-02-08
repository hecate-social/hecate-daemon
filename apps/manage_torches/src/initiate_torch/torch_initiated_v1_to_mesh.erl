%%% @doc Mesh emitter: torch_initiated_v1 → Macula Mesh
%%%
%%% Publishes torch initiation facts to mesh topic hecate.torch.initiated.
%%% This emitter is called directly after torch initiation (not via subscription)
%%% because manage_torches doesn't have a ReckonDB store yet.
%%%
%%% @end
-module(torch_initiated_v1_to_mesh).
-behaviour(gen_server).

-export([start_link/0, emit/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TOPIC, <<"hecate.torch.initiated">>).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Emit a torch initiated fact to the mesh.
%% Called after a torch is successfully initiated.
-spec emit(map()) -> ok.
emit(EventData) ->
    gen_server:cast(?MODULE, {emit, EventData}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    logger:info("[torch_initiated_v1_to_mesh] Emitter started"),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({emit, EventData}, State) ->
    case hecate_mesh_client:publish(?TOPIC, EventData) of
        ok ->
            TorchId = maps:get(<<"torch_id">>, EventData, maps:get(torch_id, EventData, <<"unknown">>)),
            logger:info("[torch_initiated_v1_to_mesh] Published torch ~s to mesh", [TorchId]);
        {error, not_connected} ->
            logger:warning("[torch_initiated_v1_to_mesh] Mesh not connected, fact not published");
        {error, Reason} ->
            logger:error("[torch_initiated_v1_to_mesh] Failed to publish: ~p", [Reason])
    end,
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
