%%% @doc event_sticky_pulled_v1 event
%%% Emitted when an event sticky is pulled (removed) during Big Picture Event Storming.
-module(event_sticky_pulled_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_sticky_id/1, get_pulled_at/1]).

-record(event_sticky_pulled_v1, {
    venture_id :: binary(),
    sticky_id  :: binary(),
    pulled_at  :: non_neg_integer()
}).

-export_type([event_sticky_pulled_v1/0]).
-opaque event_sticky_pulled_v1() :: #event_sticky_pulled_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> event_sticky_pulled_v1().
new(#{venture_id := VentureId, sticky_id := StickyId} = Params) ->
    #event_sticky_pulled_v1{
        venture_id = VentureId,
        sticky_id = StickyId,
        pulled_at = maps:get(pulled_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(event_sticky_pulled_v1()) -> map().
to_map(#event_sticky_pulled_v1{venture_id = V, sticky_id = S, pulled_at = PA}) ->
    #{
        <<"event_type">> => <<"event_sticky_pulled_v1">>,
        <<"venture_id">> => V,
        <<"sticky_id">> => S,
        <<"pulled_at">> => PA
    }.

-spec from_map(map()) -> {ok, event_sticky_pulled_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #event_sticky_pulled_v1{
                venture_id = VentureId,
                sticky_id = get_value(sticky_id, Map),
                pulled_at = get_value(pulled_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(event_sticky_pulled_v1()) -> binary().
get_venture_id(#event_sticky_pulled_v1{venture_id = V}) -> V.

-spec get_sticky_id(event_sticky_pulled_v1()) -> binary().
get_sticky_id(#event_sticky_pulled_v1{sticky_id = V}) -> V.

-spec get_pulled_at(event_sticky_pulled_v1()) -> non_neg_integer().
get_pulled_at(#event_sticky_pulled_v1{pulled_at = V}) -> V.

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
