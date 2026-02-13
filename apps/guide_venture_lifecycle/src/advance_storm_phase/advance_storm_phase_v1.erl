%%% @doc advance_storm_phase_v1 command
%%% Advances the storm phase during Big Picture Event Storming.
-module(advance_storm_phase_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_target_phase/1]).

-record(advance_storm_phase_v1, {
    venture_id   :: binary(),
    target_phase :: binary()
}).

-export_type([advance_storm_phase_v1/0]).
-opaque advance_storm_phase_v1() :: #advance_storm_phase_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, advance_storm_phase_v1()} | {error, term()}.
new(#{venture_id := VentureId, target_phase := TargetPhase}) ->
    Cmd = #advance_storm_phase_v1{
        venture_id = VentureId,
        target_phase = TargetPhase
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(advance_storm_phase_v1()) -> ok | {error, term()}.
validate(#advance_storm_phase_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#advance_storm_phase_v1{target_phase = T}) when not is_binary(T); T =:= <<>> ->
    {error, {invalid_field, target_phase}};
validate(#advance_storm_phase_v1{target_phase = T}) ->
    ValidPhases = [<<"stack">>, <<"groom">>, <<"cluster">>, <<"name">>, <<"map">>, <<"promoted">>],
    case lists:member(T, ValidPhases) of
        true -> ok;
        false -> {error, {invalid_phase, T}}
    end.

-spec to_map(advance_storm_phase_v1()) -> map().
to_map(#advance_storm_phase_v1{venture_id = V, target_phase = T}) ->
    #{
        <<"command_type">> => <<"advance_storm_phase">>,
        <<"venture_id">> => V,
        <<"target_phase">> => T
    }.

-spec from_map(map()) -> {ok, advance_storm_phase_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    TargetPhase = get_value(target_phase, Map),
    case {VentureId, TargetPhase} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, target_phase => TargetPhase})
    end.

-spec get_venture_id(advance_storm_phase_v1()) -> binary().
get_venture_id(#advance_storm_phase_v1{venture_id = V}) -> V.

-spec get_target_phase(advance_storm_phase_v1()) -> binary().
get_target_phase(#advance_storm_phase_v1{target_phase = V}) -> V.

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
