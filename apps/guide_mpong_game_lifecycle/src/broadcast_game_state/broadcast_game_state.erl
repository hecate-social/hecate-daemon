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
    %%
    %% Integer keys in the per-wall sub-maps (alive, paddles, points,
    %% games_won) trip macula_frame:wire_key/1 (no clause for plain
    %% integers, only atoms / binaries / `{text, _}'). Stringify them
    %% before publish; the realm-side decoder reverses with
    %% integer_to_binary round-trip. Without this normalisation every
    %% state-broadcast publish crashes the peering_conn and tears down
    %% all subscriptions on that link.
    Payload = stringify_int_keys(StateMsg#{<<"game_id">> => GameId}),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true ->
            hecate_mesh:publish(topic(), Payload);
        false ->
            ok
    end.

%% Recursively walk a map / list and rewrite any integer map keys to
%% their decimal binary form. Atom and binary keys pass through. Values
%% recurse so nested per-wall maps are reached.
stringify_int_keys(Map) when is_map(Map) ->
    maps:fold(fun(K, V, Acc) ->
        K2 = case K of
                 I when is_integer(I) -> integer_to_binary(I);
                 Other                -> Other
             end,
        Acc#{K2 => stringify_int_keys(V)}
    end, #{}, Map);
stringify_int_keys(List) when is_list(List) ->
    [stringify_int_keys(E) || E <- List];
stringify_int_keys(Other) ->
    Other.
