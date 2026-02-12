%%% @doc Mesh emitter: division_initiated_v1 -> Macula Mesh
%%%
%%% Publishes division initiated facts to mesh topic hecate.division.initiated.
%%% @end
-module(division_initiated_v1_to_mesh).
-behaviour(gen_server).

-export([start_link/0, emit/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TOPIC, <<"hecate.division.initiated">>).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Emit a division initiated fact to the mesh.
-spec emit(map()) -> ok.
emit(EventData) ->
    gen_server:cast(?MODULE, {emit, EventData}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    logger:info("[division_initiated_v1_to_mesh] Emitter started"),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({emit, EventData}, State) ->
    case hecate_mesh_client:publish(?TOPIC, EventData) of
        ok ->
            DivisionId = maps:get(<<"division_id">>, EventData, maps:get(division_id, EventData, <<"unknown">>)),
            logger:info("[division_initiated_v1_to_mesh] Published division ~s to mesh", [DivisionId]);
        {error, not_connected} ->
            logger:warning("[division_initiated_v1_to_mesh] Mesh not connected, fact not published");
        {error, Reason} ->
            logger:error("[division_initiated_v1_to_mesh] Failed to publish: ~p", [Reason])
    end,
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
