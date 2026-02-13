%%% @doc big_picture_storm_shelved_v1 event
%%% Emitted when a Big Picture Event Storming session is shelved for a venture.
-module(big_picture_storm_shelved_v1).

-export([new/1, from_map/1, to_map/1, get_venture_id/1, get_reason/1, get_shelved_at/1]).

-record(big_picture_storm_shelved_v1, {
    venture_id :: binary(),
    reason     :: binary() | undefined,
    shelved_at :: non_neg_integer()
}).

-export_type([big_picture_storm_shelved_v1/0]).
-opaque big_picture_storm_shelved_v1() :: #big_picture_storm_shelved_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> big_picture_storm_shelved_v1().
new(#{venture_id := VentureId} = Params) ->
    #big_picture_storm_shelved_v1{
        venture_id = VentureId,
        reason = maps:get(reason, Params, undefined),
        shelved_at = maps:get(shelved_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(big_picture_storm_shelved_v1()) -> map().
to_map(#big_picture_storm_shelved_v1{venture_id = V, reason = R, shelved_at = SA}) ->
    #{
        <<"event_type">> => <<"big_picture_storm_shelved_v1">>,
        <<"venture_id">> => V,
        <<"reason">> => R,
        <<"shelved_at">> => SA
    }.

-spec from_map(map()) -> {ok, big_picture_storm_shelved_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #big_picture_storm_shelved_v1{
                venture_id = VentureId,
                reason = get_value(reason, Map),
                shelved_at = get_value(shelved_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(big_picture_storm_shelved_v1()) -> binary().
get_venture_id(#big_picture_storm_shelved_v1{venture_id = V}) -> V.

-spec get_reason(big_picture_storm_shelved_v1()) -> binary() | undefined.
get_reason(#big_picture_storm_shelved_v1{reason = V}) -> V.

-spec get_shelved_at(big_picture_storm_shelved_v1()) -> non_neg_integer().
get_shelved_at(#big_picture_storm_shelved_v1{shelved_at = V}) -> V.

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
