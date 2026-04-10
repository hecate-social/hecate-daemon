%%%-------------------------------------------------------------------
%%% @doc Listens to game state from mesh on NON-HOST nodes.
%%%
%%% Subscribes to mpong/state_broadcast_v1 topic.
%%% Filters by game_id in payload. Receives game state, runs local
%%% AI, sends paddle position back.
%%%
%%% Subscribe: {realm}/hecate-social/hecate/mpong/state_broadcast_v1
%%% Publish:   {realm}/hecate-social/hecate/mpong/paddle_moved_v1
%%% @end
%%%-------------------------------------------------------------------
-module(listen_game_state).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(listener, {
    game_id    :: binary(),
    wall_index :: non_neg_integer(),
    arena      :: term() | undefined
}).

start_link(#{game_id := GameId, wall_index := WallIndex}) ->
    gen_server:start_link(?MODULE, #{game_id => GameId, wall_index => WallIndex}, []).

init(#{game_id := GameId, wall_index := WallIndex}) ->
    Topic = broadcast_game_state:topic(),
    case erlang:function_exported(hecate_mesh, subscribe, 2) of
        true ->
            Self = self(),
            hecate_mesh:subscribe(Topic, fun(Msg) -> Self ! {mesh_state, Msg} end);
        false -> ok
    end,
    pg:join(pg, {mpong_game_stream, GameId}, self()),
    logger:info("[mpong] Listener started for game ~s wall ~b", [GameId, WallIndex]),
    {ok, #listener{game_id = GameId, wall_index = WallIndex}}.

handle_call(_Req, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({mesh_state, #{payload := Payload}}, State) ->
    handle_game_state(Payload, State);
handle_info({mesh_state, Payload}, State) when is_binary(Payload) ->
    handle_game_state(json:decode(Payload), State);
handle_info({mesh_state, Payload}, State) when is_map(Payload) ->
    handle_game_state(Payload, State);
handle_info(_Info, State) ->
    {noreply, State}.

%% Only process ticks for OUR game
handle_game_state(#{<<"game_id">> := GID, <<"ball">> := Ball} = StateMsg,
                  #listener{game_id = GameId} = State) when GID =:= GameId ->
    Members = pg:get_members(pg, {mpong_game_stream, GameId}),
    [Pid ! {mpong_state, GameId, StateMsg} || Pid <- Members, Pid =/= self()],
    Arena = case State#listener.arena of
        undefined -> mpong_arena:new(maps:size(maps:get(<<"paddles">>, StateMsg, #{})));
        A -> A
    end,
    PaddlePos = mpong_ai:compute_paddle_position(Ball, State#listener.wall_index, Arena),
    send_paddle(GameId, PaddlePos),
    {noreply, State#listener{arena = Arena}};
handle_game_state(_, State) ->
    {noreply, State}.

terminate(_Reason, #listener{game_id = GameId}) ->
    pg:leave(pg, {mpong_game_stream, GameId}, self()),
    ok.

send_paddle(GameId, Position) ->
    Topic = handle_paddle_input:topic(),
    NodeId = atom_to_binary(node()),
    Payload = json:encode(#{game_id => GameId, node_id => NodeId, position => Position}),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true -> hecate_mesh:publish(Topic, Payload);
        false -> ok
    end.
