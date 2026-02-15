%%% @doc duel_started_v1 event
%%% Emitted when a snake duel is successfully started.
-module(duel_started_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_match_id/1, get_af1/1, get_af2/1, get_tick_ms/1, get_started_at/1]).

-record(duel_started_v1, {
    match_id   :: binary(),
    af1        :: non_neg_integer(),
    af2        :: non_neg_integer(),
    tick_ms    :: non_neg_integer(),
    started_at :: integer()
}).

-export_type([duel_started_v1/0]).
-opaque duel_started_v1() :: #duel_started_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> duel_started_v1().
new(#{match_id := MatchId} = Params) ->
    #duel_started_v1{
        match_id = MatchId,
        af1 = maps:get(af1, Params, 50),
        af2 = maps:get(af2, Params, 50),
        tick_ms = maps:get(tick_ms, Params, 100),
        started_at = erlang:system_time(millisecond)
    }.

-spec to_map(duel_started_v1()) -> map().
to_map(#duel_started_v1{} = E) ->
    #{
        <<"event_type">> => <<"duel_started_v1">>,
        <<"match_id">> => E#duel_started_v1.match_id,
        <<"af1">> => E#duel_started_v1.af1,
        <<"af2">> => E#duel_started_v1.af2,
        <<"tick_ms">> => E#duel_started_v1.tick_ms,
        <<"started_at">> => E#duel_started_v1.started_at
    }.

-spec from_map(map()) -> {ok, duel_started_v1()} | {error, term()}.
from_map(Map) ->
    MatchId = get_val(match_id, Map),
    case MatchId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #duel_started_v1{
                match_id = MatchId,
                af1 = get_val(af1, Map, 50),
                af2 = get_val(af2, Map, 50),
                tick_ms = get_val(tick_ms, Map, 100),
                started_at = get_val(started_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_match_id(duel_started_v1()) -> binary().
get_match_id(#duel_started_v1{match_id = V}) -> V.

-spec get_af1(duel_started_v1()) -> non_neg_integer().
get_af1(#duel_started_v1{af1 = V}) -> V.

-spec get_af2(duel_started_v1()) -> non_neg_integer().
get_af2(#duel_started_v1{af2 = V}) -> V.

-spec get_tick_ms(duel_started_v1()) -> non_neg_integer().
get_tick_ms(#duel_started_v1{tick_ms = V}) -> V.

-spec get_started_at(duel_started_v1()) -> integer().
get_started_at(#duel_started_v1{started_at = V}) -> V.

%% Internal
get_val(Key, Map) -> get_val(Key, Map, undefined).
get_val(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
