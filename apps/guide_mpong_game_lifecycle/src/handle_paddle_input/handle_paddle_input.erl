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

-spec handle_message(term(), pid()) -> ok.
handle_message(#{payload := Payload}, EnginePid) ->
    handle_paddle(Payload, EnginePid);
handle_message(Payload, EnginePid) when is_binary(Payload) ->
    handle_paddle(json:decode(Payload), EnginePid);
handle_message(Payload, EnginePid) when is_map(Payload) ->
    handle_paddle(Payload, EnginePid);
handle_message(_, _) -> ok.

handle_paddle(#{<<"node_id">> := NodeId, <<"position">> := Pos}, EnginePid) ->
    mpong_game_engine:update_paddle(EnginePid, NodeId, Pos);
handle_paddle(_, _) -> ok.
