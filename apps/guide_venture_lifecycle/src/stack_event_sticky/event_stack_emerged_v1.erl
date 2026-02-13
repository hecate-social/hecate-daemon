%%% @doc event_stack_emerged_v1 event
%%% Emitted when a new stack emerges during Big Picture Event Storming.
-module(event_stack_emerged_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_stack_id/1, get_color/1,
         get_sticky_ids/1, get_emerged_at/1]).

-record(event_stack_emerged_v1, {
    venture_id :: binary(),
    stack_id   :: binary(),
    color      :: binary(),
    sticky_ids :: [binary()],
    emerged_at :: non_neg_integer()
}).

-export_type([event_stack_emerged_v1/0]).
-opaque event_stack_emerged_v1() :: #event_stack_emerged_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-define(PALETTE, [
    <<"#FF6B35">>, <<"#F7C59F">>, <<"#EFEFD0">>, <<"#004E89">>,
    <<"#1A659E">>, <<"#FF6B6B">>, <<"#C44D58">>, <<"#556270">>,
    <<"#4ECDC4">>, <<"#FFE66D">>, <<"#95E1D3">>, <<"#F38181">>
]).

-spec new(map()) -> event_stack_emerged_v1().
new(#{venture_id := VentureId} = Params) ->
    #event_stack_emerged_v1{
        venture_id = VentureId,
        stack_id = maps:get(stack_id, Params, generate_id(<<"stack-">>)),
        color = maps:get(color, Params, random_color()),
        sticky_ids = maps:get(sticky_ids, Params, []),
        emerged_at = maps:get(emerged_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(event_stack_emerged_v1()) -> map().
to_map(#event_stack_emerged_v1{venture_id = V, stack_id = SI, color = C,
                                sticky_ids = Ids, emerged_at = EA}) ->
    #{
        <<"event_type">> => <<"event_stack_emerged_v1">>,
        <<"venture_id">> => V,
        <<"stack_id">> => SI,
        <<"color">> => C,
        <<"sticky_ids">> => Ids,
        <<"emerged_at">> => EA
    }.

-spec from_map(map()) -> {ok, event_stack_emerged_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #event_stack_emerged_v1{
                venture_id = VentureId,
                stack_id = get_value(stack_id, Map),
                color = get_value(color, Map, random_color()),
                sticky_ids = get_value(sticky_ids, Map, []),
                emerged_at = get_value(emerged_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(event_stack_emerged_v1()) -> binary().
get_venture_id(#event_stack_emerged_v1{venture_id = V}) -> V.

-spec get_stack_id(event_stack_emerged_v1()) -> binary().
get_stack_id(#event_stack_emerged_v1{stack_id = V}) -> V.

-spec get_color(event_stack_emerged_v1()) -> binary().
get_color(#event_stack_emerged_v1{color = V}) -> V.

-spec get_sticky_ids(event_stack_emerged_v1()) -> [binary()].
get_sticky_ids(#event_stack_emerged_v1{sticky_ids = V}) -> V.

-spec get_emerged_at(event_stack_emerged_v1()) -> non_neg_integer().
get_emerged_at(#event_stack_emerged_v1{emerged_at = V}) -> V.

generate_id(Prefix) ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<Prefix/binary, Ts/binary, "-", Rand/binary>>.

random_color() ->
    Palette = ?PALETTE,
    Idx = rand:uniform(length(Palette)),
    lists:nth(Idx, Palette).

%% Internal helper to get value with atom or binary key
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
