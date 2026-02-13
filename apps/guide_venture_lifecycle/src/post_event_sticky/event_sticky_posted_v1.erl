%%% @doc event_sticky_posted_v1 event
%%% Emitted when an event sticky is posted during Big Picture Event Storming.
-module(event_sticky_posted_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_sticky_id/1, get_text/1,
         get_author/1, get_storm_number/1, get_created_at/1]).

-record(event_sticky_posted_v1, {
    venture_id   :: binary(),
    sticky_id    :: binary(),
    text         :: binary(),
    author       :: binary(),
    storm_number :: non_neg_integer(),
    created_at   :: non_neg_integer()
}).

-export_type([event_sticky_posted_v1/0]).
-opaque event_sticky_posted_v1() :: #event_sticky_posted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> event_sticky_posted_v1().
new(#{venture_id := VentureId, text := Text} = Params) ->
    #event_sticky_posted_v1{
        venture_id = VentureId,
        sticky_id = maps:get(sticky_id, Params, generate_id(<<"sticky-">>)),
        text = Text,
        author = maps:get(author, Params, <<"user">>),
        storm_number = maps:get(storm_number, Params, 0),
        created_at = maps:get(created_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(event_sticky_posted_v1()) -> map().
to_map(#event_sticky_posted_v1{venture_id = V, sticky_id = SI, text = T,
                                author = A, storm_number = SN, created_at = CA}) ->
    #{
        <<"event_type">> => <<"event_sticky_posted_v1">>,
        <<"venture_id">> => V,
        <<"sticky_id">> => SI,
        <<"text">> => T,
        <<"author">> => A,
        <<"storm_number">> => SN,
        <<"created_at">> => CA
    }.

-spec from_map(map()) -> {ok, event_sticky_posted_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #event_sticky_posted_v1{
                venture_id = VentureId,
                sticky_id = get_value(sticky_id, Map),
                text = get_value(text, Map),
                author = get_value(author, Map, <<"user">>),
                storm_number = get_value(storm_number, Map, 0),
                created_at = get_value(created_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(event_sticky_posted_v1()) -> binary().
get_venture_id(#event_sticky_posted_v1{venture_id = V}) -> V.

-spec get_sticky_id(event_sticky_posted_v1()) -> binary().
get_sticky_id(#event_sticky_posted_v1{sticky_id = V}) -> V.

-spec get_text(event_sticky_posted_v1()) -> binary().
get_text(#event_sticky_posted_v1{text = V}) -> V.

-spec get_author(event_sticky_posted_v1()) -> binary().
get_author(#event_sticky_posted_v1{author = V}) -> V.

-spec get_storm_number(event_sticky_posted_v1()) -> non_neg_integer().
get_storm_number(#event_sticky_posted_v1{storm_number = V}) -> V.

-spec get_created_at(event_sticky_posted_v1()) -> non_neg_integer().
get_created_at(#event_sticky_posted_v1{created_at = V}) -> V.

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
