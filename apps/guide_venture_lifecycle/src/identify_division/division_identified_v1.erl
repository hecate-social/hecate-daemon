%%% @doc division_identified_v1 event
%%% Emitted when a division is identified within a venture during discovery.
-module(division_identified_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_division_id/1, get_context_name/1,
         get_description/1, get_identified_by/1, get_identified_at/1]).

-record(division_identified_v1, {
    venture_id    :: binary(),
    division_id   :: binary(),
    context_name  :: binary(),
    description   :: binary() | undefined,
    identified_by :: binary() | undefined,
    identified_at :: non_neg_integer()
}).

-export_type([division_identified_v1/0]).
-opaque division_identified_v1() :: #division_identified_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> division_identified_v1().
new(#{venture_id := VentureId, context_name := ContextName} = Params) ->
    #division_identified_v1{
        venture_id = VentureId,
        division_id = maps:get(division_id, Params, generate_division_id()),
        context_name = ContextName,
        description = maps:get(description, Params, undefined),
        identified_by = maps:get(identified_by, Params, undefined),
        identified_at = maps:get(identified_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(division_identified_v1()) -> map().
to_map(#division_identified_v1{venture_id = V, division_id = DI, context_name = CN,
                                description = D, identified_by = IB, identified_at = IA}) ->
    #{
        <<"event_type">> => <<"division_identified_v1">>,
        <<"venture_id">> => V,
        <<"division_id">> => DI,
        <<"context_name">> => CN,
        <<"description">> => D,
        <<"identified_by">> => IB,
        <<"identified_at">> => IA
    }.

-spec from_map(map()) -> {ok, division_identified_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #division_identified_v1{
                venture_id = VentureId,
                division_id = get_value(division_id, Map),
                context_name = get_value(context_name, Map),
                description = get_value(description, Map),
                identified_by = get_value(identified_by, Map),
                identified_at = get_value(identified_at, Map)
            }}
    end.

-spec get_venture_id(division_identified_v1()) -> binary().
get_venture_id(#division_identified_v1{venture_id = V}) -> V.

-spec get_division_id(division_identified_v1()) -> binary().
get_division_id(#division_identified_v1{division_id = V}) -> V.

-spec get_context_name(division_identified_v1()) -> binary().
get_context_name(#division_identified_v1{context_name = V}) -> V.

-spec get_description(division_identified_v1()) -> binary() | undefined.
get_description(#division_identified_v1{description = V}) -> V.

-spec get_identified_by(division_identified_v1()) -> binary() | undefined.
get_identified_by(#division_identified_v1{identified_by = V}) -> V.

-spec get_identified_at(division_identified_v1()) -> non_neg_integer().
get_identified_at(#division_identified_v1{identified_at = V}) -> V.

generate_division_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"div-", Ts/binary, "-", Rand/binary>>.

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
