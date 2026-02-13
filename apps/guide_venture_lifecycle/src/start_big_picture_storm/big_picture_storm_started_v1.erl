%%% @doc big_picture_storm_started_v1 event
%%% Emitted when a Big Picture Event Storming session is started for a venture.
-module(big_picture_storm_started_v1).

-export([new/1, from_map/1, to_map/1, get_venture_id/1, get_storm_number/1, get_started_at/1]).

-record(big_picture_storm_started_v1, {
    venture_id   :: binary(),
    storm_number :: non_neg_integer(),
    started_at   :: non_neg_integer()
}).

-export_type([big_picture_storm_started_v1/0]).
-opaque big_picture_storm_started_v1() :: #big_picture_storm_started_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> big_picture_storm_started_v1().
new(#{venture_id := VentureId} = Params) ->
    #big_picture_storm_started_v1{
        venture_id = VentureId,
        storm_number = maps:get(storm_number, Params, 0),
        started_at = maps:get(started_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(big_picture_storm_started_v1()) -> map().
to_map(#big_picture_storm_started_v1{venture_id = V, storm_number = SN, started_at = SA}) ->
    #{
        <<"event_type">> => <<"big_picture_storm_started_v1">>,
        <<"venture_id">> => V,
        <<"storm_number">> => SN,
        <<"started_at">> => SA
    }.

-spec from_map(map()) -> {ok, big_picture_storm_started_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #big_picture_storm_started_v1{
                venture_id = VentureId,
                storm_number = get_value(storm_number, Map, 0),
                started_at = get_value(started_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(big_picture_storm_started_v1()) -> binary().
get_venture_id(#big_picture_storm_started_v1{venture_id = V}) -> V.

-spec get_storm_number(big_picture_storm_started_v1()) -> non_neg_integer().
get_storm_number(#big_picture_storm_started_v1{storm_number = V}) -> V.

-spec get_started_at(big_picture_storm_started_v1()) -> non_neg_integer().
get_started_at(#big_picture_storm_started_v1{started_at = V}) -> V.

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
