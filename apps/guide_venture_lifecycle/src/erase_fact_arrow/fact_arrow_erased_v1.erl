%%% @doc fact_arrow_erased_v1 event
%%% Emitted when a fact arrow is erased during Big Picture Event Storming.
-module(fact_arrow_erased_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_arrow_id/1, get_erased_at/1]).

-record(fact_arrow_erased_v1, {
    venture_id :: binary(),
    arrow_id   :: binary(),
    erased_at  :: non_neg_integer()
}).

-export_type([fact_arrow_erased_v1/0]).
-opaque fact_arrow_erased_v1() :: #fact_arrow_erased_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> fact_arrow_erased_v1().
new(#{venture_id := VentureId, arrow_id := ArrowId} = Params) ->
    #fact_arrow_erased_v1{
        venture_id = VentureId,
        arrow_id = ArrowId,
        erased_at = maps:get(erased_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(fact_arrow_erased_v1()) -> map().
to_map(#fact_arrow_erased_v1{venture_id = V, arrow_id = AI, erased_at = EA}) ->
    #{
        <<"event_type">> => <<"fact_arrow_erased_v1">>,
        <<"venture_id">> => V,
        <<"arrow_id">> => AI,
        <<"erased_at">> => EA
    }.

-spec from_map(map()) -> {ok, fact_arrow_erased_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #fact_arrow_erased_v1{
                venture_id = VentureId,
                arrow_id = get_value(arrow_id, Map),
                erased_at = get_value(erased_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(fact_arrow_erased_v1()) -> binary().
get_venture_id(#fact_arrow_erased_v1{venture_id = V}) -> V.

-spec get_arrow_id(fact_arrow_erased_v1()) -> binary().
get_arrow_id(#fact_arrow_erased_v1{arrow_id = V}) -> V.

-spec get_erased_at(fact_arrow_erased_v1()) -> non_neg_integer().
get_erased_at(#fact_arrow_erased_v1{erased_at = V}) -> V.

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
