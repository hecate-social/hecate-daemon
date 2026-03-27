%%%-------------------------------------------------------------------
%%% @doc Receives remote paddle positions from mesh PubSub.
%%%
%%% On the HOST node, subscribes to {realm}.hecate.mpong.game.paddle.
%%% Filters by game_id in payload. When a remote player sends their
%%% paddle position, forwards it to the local game engine.
%%%
%%% Topic: {realm}.hecate.mpong.game.paddle (game_id in payload)
%%% @end
%%%-------------------------------------------------------------------
-module(handle_paddle_input).

-export([subscribe/2, topic/0]).

topic() ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    <<Realm/binary, ".hecate.mpong.game.paddle">>.

-spec subscribe(binary(), pid()) -> ok.
subscribe(GameId, EnginePid) ->
    case erlang:function_exported(hecate_mesh, subscribe, 2) of
        true ->
            hecate_mesh:subscribe(topic(), fun(Msg) ->
                handle_message(Msg, GameId, EnginePid)
            end);
        false ->
            ok
    end.

handle_message(#{payload := Payload}, GameId, EnginePid) ->
    handle_paddle(Payload, GameId, EnginePid);
handle_message(Payload, GameId, EnginePid) when is_binary(Payload) ->
    handle_paddle(json:decode(Payload), GameId, EnginePid);
handle_message(Payload, GameId, EnginePid) when is_map(Payload) ->
    handle_paddle(Payload, GameId, EnginePid);
handle_message(_, _, _) -> ok.

%% Only process paddles for OUR game
handle_paddle(#{<<"game_id">> := GID, <<"node_id">> := NodeId, <<"position">> := Pos}, GameId, EnginePid)
  when GID =:= GameId ->
    mpong_game_engine:update_paddle(EnginePid, NodeId, Pos);
handle_paddle(_, _, _) -> ok.
