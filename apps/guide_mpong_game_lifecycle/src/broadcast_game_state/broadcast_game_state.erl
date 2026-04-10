%%%-------------------------------------------------------------------
%%% @doc Broadcasts game engine state to the Macula mesh.
%%%
%%% Called by mpong_game_engine every tick. Publishes ball position,
%%% paddle positions, scores, and alive status to a PubSub topic.
%%%
%%% Topic: {realm}/hecate-social/hecate/mpong/state_broadcast_v1
%%% @end
%%%-------------------------------------------------------------------
-module(broadcast_game_state).

-export([broadcast/2, topic/0]).

topic() ->
    hecate_topics:fact(<<"mpong">>, <<"state_broadcast">>, 1).

-spec broadcast(binary(), map()) -> ok.
broadcast(GameId, StateMsg) ->
    Payload = json:encode(StateMsg#{<<"game_id">> => GameId}),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true ->
            hecate_mesh:publish(topic(), Payload);
        false ->
            ok
    end.
