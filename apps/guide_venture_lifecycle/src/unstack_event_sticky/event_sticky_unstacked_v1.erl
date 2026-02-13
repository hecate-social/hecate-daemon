%%% @doc event_sticky_unstacked_v1 event
%%% Emitted when an event sticky is removed from its stack during Big Picture Event Storming.
-module(event_sticky_unstacked_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_sticky_id/1, get_stack_id/1, get_unstacked_at/1]).

-record(event_sticky_unstacked_v1, {
    venture_id  :: binary(),
    sticky_id   :: binary(),
    stack_id    :: binary(),
    unstacked_at :: non_neg_integer()
}).

-export_type([event_sticky_unstacked_v1/0]).
-opaque event_sticky_unstacked_v1() :: #event_sticky_unstacked_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> event_sticky_unstacked_v1().
new(#{venture_id := VentureId, sticky_id := StickyId, stack_id := StackId} = Params) ->
    #event_sticky_unstacked_v1{
        venture_id = VentureId,
        sticky_id = StickyId,
        stack_id = StackId,
        unstacked_at = maps:get(unstacked_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(event_sticky_unstacked_v1()) -> map().
to_map(#event_sticky_unstacked_v1{venture_id = V, sticky_id = SI,
                                   stack_id = StI, unstacked_at = UA}) ->
    #{
        <<"event_type">> => <<"event_sticky_unstacked_v1">>,
        <<"venture_id">> => V,
        <<"sticky_id">> => SI,
        <<"stack_id">> => StI,
        <<"unstacked_at">> => UA
    }.

-spec from_map(map()) -> {ok, event_sticky_unstacked_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #event_sticky_unstacked_v1{
                venture_id = VentureId,
                sticky_id = get_value(sticky_id, Map),
                stack_id = get_value(stack_id, Map),
                unstacked_at = get_value(unstacked_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(event_sticky_unstacked_v1()) -> binary().
get_venture_id(#event_sticky_unstacked_v1{venture_id = V}) -> V.

-spec get_sticky_id(event_sticky_unstacked_v1()) -> binary().
get_sticky_id(#event_sticky_unstacked_v1{sticky_id = V}) -> V.

-spec get_stack_id(event_sticky_unstacked_v1()) -> binary().
get_stack_id(#event_sticky_unstacked_v1{stack_id = V}) -> V.

-spec get_unstacked_at(event_sticky_unstacked_v1()) -> non_neg_integer().
get_unstacked_at(#event_sticky_unstacked_v1{unstacked_at = V}) -> V.

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
