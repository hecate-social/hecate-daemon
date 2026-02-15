%%% @doc fact_arrow_drawn_v1 event
%%% Emitted when a fact arrow is drawn between clusters during Big Picture Event Storming.
-module(fact_arrow_drawn_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_arrow_id/1, get_from_cluster/1,
         get_to_cluster/1, get_fact_name/1, get_drawn_at/1]).

-record(fact_arrow_drawn_v1, {
    venture_id   :: binary(),
    storm_number :: non_neg_integer(),
    arrow_id     :: binary(),
    from_cluster :: binary(),
    to_cluster   :: binary(),
    fact_name    :: binary(),
    drawn_at     :: non_neg_integer()
}).

-export_type([fact_arrow_drawn_v1/0]).
-opaque fact_arrow_drawn_v1() :: #fact_arrow_drawn_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> fact_arrow_drawn_v1().
new(#{venture_id := VentureId, from_cluster := FromCluster,
      to_cluster := ToCluster, fact_name := FactName} = Params) ->
    #fact_arrow_drawn_v1{
        venture_id = VentureId,
        storm_number = maps:get(storm_number, Params, 0),
        arrow_id = maps:get(arrow_id, Params, generate_id(<<"arrow-">>)),
        from_cluster = FromCluster,
        to_cluster = ToCluster,
        fact_name = FactName,
        drawn_at = maps:get(drawn_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(fact_arrow_drawn_v1()) -> map().
to_map(#fact_arrow_drawn_v1{venture_id = V, storm_number = SN, arrow_id = AI,
                             from_cluster = FC, to_cluster = TC, fact_name = FN,
                             drawn_at = DA}) ->
    #{
        <<"event_type">> => <<"fact_arrow_drawn_v1">>,
        <<"venture_id">> => V,
        <<"storm_number">> => SN,
        <<"arrow_id">> => AI,
        <<"from_cluster">> => FC,
        <<"to_cluster">> => TC,
        <<"fact_name">> => FN,
        <<"drawn_at">> => DA
    }.

-spec from_map(map()) -> {ok, fact_arrow_drawn_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #fact_arrow_drawn_v1{
                venture_id = VentureId,
                storm_number = get_value(storm_number, Map, 0),
                arrow_id = get_value(arrow_id, Map),
                from_cluster = get_value(from_cluster, Map),
                to_cluster = get_value(to_cluster, Map),
                fact_name = get_value(fact_name, Map),
                drawn_at = get_value(drawn_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(fact_arrow_drawn_v1()) -> binary().
get_venture_id(#fact_arrow_drawn_v1{venture_id = V}) -> V.

-spec get_arrow_id(fact_arrow_drawn_v1()) -> binary().
get_arrow_id(#fact_arrow_drawn_v1{arrow_id = V}) -> V.

-spec get_from_cluster(fact_arrow_drawn_v1()) -> binary().
get_from_cluster(#fact_arrow_drawn_v1{from_cluster = V}) -> V.

-spec get_to_cluster(fact_arrow_drawn_v1()) -> binary().
get_to_cluster(#fact_arrow_drawn_v1{to_cluster = V}) -> V.

-spec get_fact_name(fact_arrow_drawn_v1()) -> binary().
get_fact_name(#fact_arrow_drawn_v1{fact_name = V}) -> V.

-spec get_drawn_at(fact_arrow_drawn_v1()) -> non_neg_integer().
get_drawn_at(#fact_arrow_drawn_v1{drawn_at = V}) -> V.

generate_id(Prefix) ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<Prefix/binary, Ts/binary, "-", Rand/binary>>.

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
