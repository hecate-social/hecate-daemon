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
    %%
    %% Engine ticks at 25Hz. Publishing every tick (25 publishes/sec)
    %% appears to exceed something in the macula-station pubsub
    %% fanout — events return `ok' at the daemon SDK layer but never
    %% reach realm-side subscribers. Throttle to every 5th tick = 5Hz,
    %% which is still smooth enough for a spectator view and well
    %% under whatever the station-side rate-gate is. Last tick of the
    %% game always fires so end-state reaches subscribers.
    Tick = maps:get(tick, StateMsg, 0),
    ShouldPublish = (Tick rem 5) =:= 0,
    case erlang:function_exported(hecate_mesh, publish, 2) andalso ShouldPublish of
        true ->
            Payload = StateMsg#{<<"game_id">> => GameId},
            Result = hecate_mesh:publish(topic(), Payload),
            %% Diagnostic: log every 25th broadcast (~1Hz at 5Hz publish
            %% rate). Remove once the realm-side state cache is reliably
            %% populated.
            case Tick rem 25 of
                0 -> logger:info("[broadcast_game_state] tick=~p result=~p",
                                  [Tick, Result]);
                _ -> ok
            end,
            Result;
        false ->
            ok
    end.
