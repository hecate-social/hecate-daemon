%%%-------------------------------------------------------------------
%%% @doc Broadcasts game engine state to the Macula mesh.
%%%
%%% Called by mpong_game_engine every tick. Publishes ball position,
%%% paddle positions, scores, and alive status to a PubSub topic.
%%%
%%% Topic: mpong.game.{game_id}.state
%%% @end
%%%-------------------------------------------------------------------
-module(broadcast_game_state).

-export([broadcast/2]).

-spec broadcast(binary(), map()) -> ok.
broadcast(GameId, StateMsg) ->
    Topic = <<"mpong.game.", GameId/binary, ".state">>,
    Payload = json:encode(StateMsg),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true ->
            hecate_mesh:publish(Topic, Payload);
        false ->
            %% Mesh not available — local-only mode
            ok
    end.
