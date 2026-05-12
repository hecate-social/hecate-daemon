%%%-------------------------------------------------------------------
%%% @doc Advertises available games on the Macula mesh.
%%%
%%% Publishes game-availability facts on a single canonical topic so
%%% other nodes can discover them. Joining is no longer a per-game
%%% RPC procedure — challengers publish `seat_requested_v1` with the
%%% game_id, and the host responds with `seat_reserved_v1` /
%%% `seat_denied_v1`. See request_seat/, reserve_seat/, deny_seat/
%%% desks for the protocol.
%%%
%%% Topic: io.macula/beam-campus/hecate/mpong/game_advertised_v1
%%% @end
%%%-------------------------------------------------------------------
-module(advertise_game).

-export([announce/1, closed/1, ended/1, withdraw/1, topic/0]).

%% @doc Build the realm-prefixed mesh topic for game announcements.
-spec topic() -> binary().
topic() ->
    hecate_topics:app_fact(<<"mpong">>, <<"game_advertised">>, 1).

-spec announce(map()) -> ok.
announce(#{game_id := GameId, host_node_id := HostNodeId,
           max_players := MaxPlayers} = _GameInfo) ->
    Topic = topic(),
    %% Pass the term, NOT a json:encode'd iolist — macula's V2 wire is
    %% CBOR and serializes the payload itself. A pre-encoded JSON
    %% iolist crashes macula_frame:to_wire/1 ({bad_generator,_}),
    %% which kills the peering connection in a respawn loop, so the
    %% fact never goes out and a mesh lobby sits in "waiting" forever.
    Payload = #{
        action => <<"hosted">>,
        game_id => GameId,
        host_node_id => HostNodeId,
        max_players => MaxPlayers
    },
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true ->
            Result = hecate_mesh:publish(Topic, Payload),
            logger:info("[advertise_game] Published to ~s: ~p", [Topic, Result]),
            Result;
        false ->
            logger:warning("[advertise_game] hecate_mesh:publish/2 not available"),
            ok
    end.

-spec closed(binary()) -> ok.
closed(GameId) ->
    publish_action(<<"closed">>, GameId).

-spec ended(binary()) -> ok.
ended(GameId) ->
    publish_action(<<"ended">>, GameId).

-spec withdraw(binary()) -> ok.
withdraw(GameId) ->
    publish_action(<<"withdrawn">>, GameId).

publish_action(Action, GameId) ->
    Topic = topic(),
    Payload = #{action => Action, game_id => GameId},
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true -> hecate_mesh:publish(Topic, Payload);
        false -> ok
    end.
