%%%-------------------------------------------------------------------
%%% @doc Advertises available games on the Macula mesh.
%%%
%%% After a game is hosted, publishes game availability to mesh
%%% PubSub topic so other nodes can discover it.
%%%
%%% Topic: mpong.games.available
%%% @end
%%%-------------------------------------------------------------------
-module(advertise_game).

-export([announce/1, withdraw/1, join_procedure/1, topic/0]).

%% @doc Build the mesh RPC procedure name for joining a game.
-spec join_procedure(binary()) -> binary().
join_procedure(GameId) ->
    <<"hecate.mpong.join.", GameId/binary>>.

%% @doc Build the realm-prefixed mesh topic for game announcements.
-spec topic() -> binary().
topic() ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    <<Realm/binary, ".hecate.mpong.games.available">>.

-spec announce(map()) -> ok.
announce(#{game_id := GameId, host_node_id := HostNodeId,
           max_players := MaxPlayers} = _GameInfo) ->
    Topic = topic(),
    Payload = json:encode(#{
        action => <<"hosted">>,
        game_id => GameId,
        host_node_id => HostNodeId,
        max_players => MaxPlayers,
        join_procedure => join_procedure(GameId)
    }),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true -> hecate_mesh:publish(Topic, Payload);
        false -> ok
    end.

-spec withdraw(binary()) -> ok.
withdraw(GameId) ->
    Topic = topic(),
    Payload = json:encode(#{
        action => <<"withdrawn">>,
        game_id => GameId
    }),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true -> hecate_mesh:publish(Topic, Payload);
        false -> ok
    end.
