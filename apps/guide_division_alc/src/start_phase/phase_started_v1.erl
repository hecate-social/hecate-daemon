%%% @doc phase_started_v1 event
%%% Emitted when a phase is started for a division.
-module(phase_started_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_phase/1, get_started_at/1]).

-record(phase_started_v1, {
    division_id :: binary(),
    phase       :: binary(),
    started_at  :: integer()
}).

-export_type([phase_started_v1/0]).
-opaque phase_started_v1() :: #phase_started_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> phase_started_v1().
new(#{division_id := DivisionId, phase := Phase} = _Params) ->
    #phase_started_v1{
        division_id = DivisionId,
        phase = Phase,
        started_at = erlang:system_time(millisecond)
    }.

-spec to_map(phase_started_v1()) -> map().
to_map(#phase_started_v1{} = E) ->
    #{
        <<"event_type">> => <<"phase_started_v1">>,
        <<"division_id">> => E#phase_started_v1.division_id,
        <<"phase">> => E#phase_started_v1.phase,
        <<"started_at">> => E#phase_started_v1.started_at
    }.

-spec from_map(map()) -> {ok, phase_started_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    Phase = get_value(phase, Map),
    case {DivisionId, Phase} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #phase_started_v1{
                division_id = DivisionId,
                phase = Phase,
                started_at = get_value(started_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_division_id(phase_started_v1()) -> binary().
get_division_id(#phase_started_v1{division_id = V}) -> V.

-spec get_phase(phase_started_v1()) -> binary().
get_phase(#phase_started_v1{phase = V}) -> V.

-spec get_started_at(phase_started_v1()) -> integer().
get_started_at(#phase_started_v1{started_at = V}) -> V.

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
