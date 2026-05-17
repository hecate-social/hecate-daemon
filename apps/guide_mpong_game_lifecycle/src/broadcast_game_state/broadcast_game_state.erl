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
    hecate_topics:app_fact(<<"mpong">>, <<"state_broadcast">>, 1).

-spec broadcast(binary(), map()) -> ok.
broadcast(GameId, StateMsg) ->
    %% Pass the map, not json:encode'd — macula's V2 wire is CBOR.
    %% Integer keys + negative integers in the per-wall sub-maps and
    %% ball velocity are encoded natively by macula 4.4.10+.
    Payload = StateMsg#{<<"game_id">> => GameId},
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true ->
            Result = hecate_mesh:publish(topic(), Payload),
            %% Diagnostic: log every 25th broadcast (~1Hz at 25Hz tick
            %% rate) so we can see whether publishes are reaching the
            %% wire and what the return looks like. Remove once the
            %% realm-side state cache is reliably populated.
            Tick = maps:get(tick, StateMsg, 0),
            case Tick rem 25 of
                0 -> logger:info("[broadcast_game_state] tick=~p result=~p",
                                  [Tick, Result]);
                _ -> ok
            end,
            Result;
        false ->
            ok
    end.
