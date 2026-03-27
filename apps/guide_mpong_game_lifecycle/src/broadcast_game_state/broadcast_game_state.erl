%%%-------------------------------------------------------------------
%%% @doc Broadcasts game engine state to the Macula mesh.
%%%
%%% Called by mpong_game_engine every tick. Publishes ball position,
%%% paddle positions, scores, and alive status to a PubSub topic.
%%%
%%% Topic: {realm}.hecate.mpong.game.state (game_id in payload)
%%% @end
%%%-------------------------------------------------------------------
-module(broadcast_game_state).

-export([broadcast/2, topic/0]).

topic() ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    <<Realm/binary, ".hecate.mpong.game.state">>.

-spec broadcast(binary(), map()) -> ok.
broadcast(GameId, StateMsg) ->
    Payload = json:encode(StateMsg#{<<"game_id">> => GameId}),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true ->
            hecate_mesh:publish(topic(), Payload);
        false ->
            ok
    end.
