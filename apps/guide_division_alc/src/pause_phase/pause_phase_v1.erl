%%% @doc pause_phase_v1 command
%%% Pauses a phase (dna|anp|tni|dno) for a division.
-module(pause_phase_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_phase/1, get_reason/1]).

-record(pause_phase_v1, {
    division_id :: binary(),
    phase       :: binary(),
    reason      :: binary() | undefined
}).

-export_type([pause_phase_v1/0]).
-opaque pause_phase_v1() :: #pause_phase_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, pause_phase_v1()} | {error, term()}.
new(#{division_id := DivisionId, phase := Phase} = Params) ->
    {ok, #pause_phase_v1{
        division_id = DivisionId,
        phase = Phase,
        reason = maps:get(reason, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(pause_phase_v1()) -> {ok, pause_phase_v1()} | {error, term()}.
validate(#pause_phase_v1{division_id = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_division_id};
validate(#pause_phase_v1{phase = P}) when
    P =/= <<"dna">>, P =/= <<"anp">>, P =/= <<"tni">>, P =/= <<"dno">> ->
    {error, invalid_phase};
validate(#pause_phase_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(pause_phase_v1()) -> map().
to_map(#pause_phase_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"pause_phase">>,
        <<"division_id">> => Cmd#pause_phase_v1.division_id,
        <<"phase">> => Cmd#pause_phase_v1.phase,
        <<"reason">> => Cmd#pause_phase_v1.reason
    }.

-spec from_map(map()) -> {ok, pause_phase_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    Phase = get_value(phase, Map),
    Reason = get_value(reason, Map, undefined),
    case {DivisionId, Phase} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #pause_phase_v1{
                division_id = DivisionId,
                phase = Phase,
                reason = Reason
            }}
    end.

%% Accessors
-spec get_division_id(pause_phase_v1()) -> binary().
get_division_id(#pause_phase_v1{division_id = V}) -> V.

-spec get_phase(pause_phase_v1()) -> binary().
get_phase(#pause_phase_v1{phase = V}) -> V.

-spec get_reason(pause_phase_v1()) -> binary() | undefined.
get_reason(#pause_phase_v1{reason = V}) -> V.

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
