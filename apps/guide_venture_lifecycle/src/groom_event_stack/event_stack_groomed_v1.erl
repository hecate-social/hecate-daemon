%%% @doc event_stack_groomed_v1 event
%%% Emitted when a stack is groomed: canonical sticky chosen, others absorbed.
-module(event_stack_groomed_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_stack_id/1, get_canonical_sticky_id/1,
         get_weight/1, get_absorbed_sticky_ids/1, get_groomed_at/1]).

-record(event_stack_groomed_v1, {
    venture_id          :: binary(),
    stack_id            :: binary(),
    canonical_sticky_id :: binary(),
    weight              :: non_neg_integer(),
    absorbed_sticky_ids :: [binary()],
    groomed_at          :: non_neg_integer()
}).

-export_type([event_stack_groomed_v1/0]).
-opaque event_stack_groomed_v1() :: #event_stack_groomed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> event_stack_groomed_v1().
new(#{venture_id := VentureId, stack_id := StackId,
      canonical_sticky_id := CanonicalStickyId} = Params) ->
    #event_stack_groomed_v1{
        venture_id = VentureId,
        stack_id = StackId,
        canonical_sticky_id = CanonicalStickyId,
        weight = maps:get(weight, Params, 1),
        absorbed_sticky_ids = maps:get(absorbed_sticky_ids, Params, []),
        groomed_at = maps:get(groomed_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(event_stack_groomed_v1()) -> map().
to_map(#event_stack_groomed_v1{venture_id = V, stack_id = SI,
                                canonical_sticky_id = C, weight = W,
                                absorbed_sticky_ids = A, groomed_at = GA}) ->
    #{
        <<"event_type">> => <<"event_stack_groomed_v1">>,
        <<"venture_id">> => V,
        <<"stack_id">> => SI,
        <<"canonical_sticky_id">> => C,
        <<"weight">> => W,
        <<"absorbed_sticky_ids">> => A,
        <<"groomed_at">> => GA
    }.

-spec from_map(map()) -> {ok, event_stack_groomed_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #event_stack_groomed_v1{
                venture_id = VentureId,
                stack_id = get_value(stack_id, Map),
                canonical_sticky_id = get_value(canonical_sticky_id, Map),
                weight = get_value(weight, Map, 1),
                absorbed_sticky_ids = get_value(absorbed_sticky_ids, Map, []),
                groomed_at = get_value(groomed_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(event_stack_groomed_v1()) -> binary().
get_venture_id(#event_stack_groomed_v1{venture_id = V}) -> V.

-spec get_stack_id(event_stack_groomed_v1()) -> binary().
get_stack_id(#event_stack_groomed_v1{stack_id = V}) -> V.

-spec get_canonical_sticky_id(event_stack_groomed_v1()) -> binary().
get_canonical_sticky_id(#event_stack_groomed_v1{canonical_sticky_id = V}) -> V.

-spec get_weight(event_stack_groomed_v1()) -> non_neg_integer().
get_weight(#event_stack_groomed_v1{weight = V}) -> V.

-spec get_absorbed_sticky_ids(event_stack_groomed_v1()) -> [binary()].
get_absorbed_sticky_ids(#event_stack_groomed_v1{absorbed_sticky_ids = V}) -> V.

-spec get_groomed_at(event_stack_groomed_v1()) -> non_neg_integer().
get_groomed_at(#event_stack_groomed_v1{groomed_at = V}) -> V.

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
