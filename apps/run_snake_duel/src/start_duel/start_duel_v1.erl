%%% @doc start_duel_v1 command
%%% Initiates a new snake duel.
-module(start_duel_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_match_id/1, get_af1/1, get_af2/1, get_tick_ms/1]).
-export([generate_id/0]).

-record(start_duel_v1, {
    match_id :: binary(),
    af1      :: non_neg_integer(),
    af2      :: non_neg_integer(),
    tick_ms  :: non_neg_integer()
}).

-export_type([start_duel_v1/0]).
-opaque start_duel_v1() :: #start_duel_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, start_duel_v1()} | {error, term()}.
new(Params) ->
    MatchId = maps:get(match_id, Params, generate_id()),
    AF1 = maps:get(af1, Params, 50),
    AF2 = maps:get(af2, Params, 50),
    TickMs = maps:get(tick_ms, Params, 100),
    {ok, #start_duel_v1{
        match_id = MatchId,
        af1 = AF1,
        af2 = AF2,
        tick_ms = TickMs
    }}.

-spec to_map(start_duel_v1()) -> map().
to_map(#start_duel_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"start_duel">>,
        <<"match_id">> => Cmd#start_duel_v1.match_id,
        <<"af1">> => Cmd#start_duel_v1.af1,
        <<"af2">> => Cmd#start_duel_v1.af2,
        <<"tick_ms">> => Cmd#start_duel_v1.tick_ms
    }.

-spec from_map(map()) -> {ok, start_duel_v1()} | {error, term()}.
from_map(Map) ->
    MatchId = get_val(match_id, Map, generate_id()),
    AF1 = get_val(af1, Map, 50),
    AF2 = get_val(af2, Map, 50),
    TickMs = get_val(tick_ms, Map, 100),
    {ok, #start_duel_v1{
        match_id = MatchId,
        af1 = AF1,
        af2 = AF2,
        tick_ms = TickMs
    }}.

%% Accessors
-spec get_match_id(start_duel_v1()) -> binary().
get_match_id(#start_duel_v1{match_id = V}) -> V.

-spec get_af1(start_duel_v1()) -> non_neg_integer().
get_af1(#start_duel_v1{af1 = V}) -> V.

-spec get_af2(start_duel_v1()) -> non_neg_integer().
get_af2(#start_duel_v1{af2 = V}) -> V.

-spec get_tick_ms(start_duel_v1()) -> non_neg_integer().
get_tick_ms(#start_duel_v1{tick_ms = V}) -> V.

-spec generate_id() -> binary().
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"duel-", Ts/binary, "-", Rand/binary>>.

%% Internal
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
