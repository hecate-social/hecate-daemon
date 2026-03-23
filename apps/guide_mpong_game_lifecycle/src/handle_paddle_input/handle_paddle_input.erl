%%%-------------------------------------------------------------------
%%% @doc Receives remote paddle positions from mesh PubSub.
%%%
%%% On the HOST node, subscribes to mpong.game.{game_id}.paddle.
%%% When a remote player sends their paddle position, forwards it
%%% to the local game engine.
%%%
%%% Topic: mpong.game.{game_id}.paddle
%%% @end
%%%-------------------------------------------------------------------
-module(handle_paddle_input).

-export([subscribe/2, handle_message/2]).

-spec subscribe(binary(), pid()) -> ok.
subscribe(GameId, EnginePid) ->
    Topic = <<"mpong.game.", GameId/binary, ".paddle">>,
    case erlang:function_exported(hecate_mesh, subscribe, 2) of
        true ->
            hecate_mesh:subscribe(Topic, fun(Msg) ->
                handle_message(Msg, EnginePid)
            end);
        false ->
            ok
    end.

-spec handle_message(binary(), pid()) -> ok.
handle_message(Payload, EnginePid) ->
    case json:decode(Payload) of
        #{<<"node_id">> := NodeId, <<"position">> := Pos} ->
            mpong_game_engine:update_paddle(EnginePid, NodeId, Pos);
        _ ->
            ok
    end.
