%%% @doc storm_phase_advanced_v1 event
%%% Emitted when the storm phase advances during Big Picture Event Storming.
-module(storm_phase_advanced_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_phase/1, get_previous_phase/1, get_advanced_at/1]).

-record(storm_phase_advanced_v1, {
    venture_id     :: binary(),
    phase          :: binary(),
    previous_phase :: binary(),
    advanced_at    :: non_neg_integer()
}).

-export_type([storm_phase_advanced_v1/0]).
-opaque storm_phase_advanced_v1() :: #storm_phase_advanced_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> storm_phase_advanced_v1().
new(#{venture_id := VentureId, phase := Phase} = Params) ->
    #storm_phase_advanced_v1{
        venture_id = VentureId,
        phase = Phase,
        previous_phase = maps:get(previous_phase, Params, <<"storm">>),
        advanced_at = maps:get(advanced_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(storm_phase_advanced_v1()) -> map().
to_map(#storm_phase_advanced_v1{venture_id = V, phase = P,
                                 previous_phase = PP, advanced_at = AA}) ->
    #{
        <<"event_type">> => <<"storm_phase_advanced_v1">>,
        <<"venture_id">> => V,
        <<"phase">> => P,
        <<"previous_phase">> => PP,
        <<"advanced_at">> => AA
    }.

-spec from_map(map()) -> {ok, storm_phase_advanced_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #storm_phase_advanced_v1{
                venture_id = VentureId,
                phase = get_value(phase, Map),
                previous_phase = get_value(previous_phase, Map, <<"storm">>),
                advanced_at = get_value(advanced_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(storm_phase_advanced_v1()) -> binary().
get_venture_id(#storm_phase_advanced_v1{venture_id = V}) -> V.

-spec get_phase(storm_phase_advanced_v1()) -> binary().
get_phase(#storm_phase_advanced_v1{phase = V}) -> V.

-spec get_previous_phase(storm_phase_advanced_v1()) -> binary().
get_previous_phase(#storm_phase_advanced_v1{previous_phase = V}) -> V.

-spec get_advanced_at(storm_phase_advanced_v1()) -> non_neg_integer().
get_advanced_at(#storm_phase_advanced_v1{advanced_at = V}) -> V.

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
