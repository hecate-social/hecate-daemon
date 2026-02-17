%%% @doc Command: Start a champion duel match.
%%%
%%% Triggers a live duel between a trained champion (neural network)
%%% and a heuristic AI opponent.
%%% @end
-module(start_champion_duel_v1).

-export([new/1, stable_id/1, opponent_af/1, tick_ms/1, rank/1]).

-record(start_champion_duel_v1, {
    stable_id   :: binary(),
    opponent_af :: non_neg_integer(),
    tick_ms     :: non_neg_integer(),
    rank        :: pos_integer()
}).

-spec new(map()) -> #start_champion_duel_v1{}.
new(#{stable_id := StableId} = Params) ->
    #start_champion_duel_v1{
        stable_id = StableId,
        opponent_af = maps:get(opponent_af, Params, 50),
        tick_ms = maps:get(tick_ms, Params, 100),
        rank = maps:get(rank, Params, 1)
    }.

-spec stable_id(#start_champion_duel_v1{}) -> binary().
stable_id(#start_champion_duel_v1{stable_id = V}) -> V.

-spec opponent_af(#start_champion_duel_v1{}) -> non_neg_integer().
opponent_af(#start_champion_duel_v1{opponent_af = V}) -> V.

-spec tick_ms(#start_champion_duel_v1{}) -> non_neg_integer().
tick_ms(#start_champion_duel_v1{tick_ms = V}) -> V.

-spec rank(#start_champion_duel_v1{}) -> pos_integer().
rank(#start_champion_duel_v1{rank = V}) -> V.
