%%% @doc complete_phase_v1 command
%%% Completes a phase (dna|anp|tni|dno) for a division.
-module(complete_phase_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_phase/1]).

-record(complete_phase_v1, {
    division_id :: binary(),
    phase       :: binary()
}).

-export_type([complete_phase_v1/0]).
-opaque complete_phase_v1() :: #complete_phase_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, complete_phase_v1()} | {error, term()}.
new(#{division_id := DivisionId, phase := Phase} = _Params) ->
    {ok, #complete_phase_v1{
        division_id = DivisionId,
        phase = Phase
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(complete_phase_v1()) -> {ok, complete_phase_v1()} | {error, term()}.
validate(#complete_phase_v1{division_id = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_division_id};
validate(#complete_phase_v1{phase = P}) when
    P =/= <<"dna">>, P =/= <<"anp">>, P =/= <<"tni">>, P =/= <<"dno">> ->
    {error, invalid_phase};
validate(#complete_phase_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(complete_phase_v1()) -> map().
to_map(#complete_phase_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"complete_phase">>,
        <<"division_id">> => Cmd#complete_phase_v1.division_id,
        <<"phase">> => Cmd#complete_phase_v1.phase
    }.

-spec from_map(map()) -> {ok, complete_phase_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    Phase = get_value(phase, Map),
    case {DivisionId, Phase} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #complete_phase_v1{
                division_id = DivisionId,
                phase = Phase
            }}
    end.

%% Accessors
-spec get_division_id(complete_phase_v1()) -> binary().
get_division_id(#complete_phase_v1{division_id = V}) -> V.

-spec get_phase(complete_phase_v1()) -> binary().
get_phase(#complete_phase_v1{phase = V}) -> V.

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
