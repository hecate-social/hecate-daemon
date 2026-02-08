%%% @doc phase_transitioned_v1 event
%%% Emitted when the project transitions from one ALC phase to another.
-module(phase_transitioned_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_from_phase/1, get_to_phase/1, get_transitioned_at/1]).

-record(phase_transitioned_v1, {
    cartwheel_id      :: binary(),
    from_phase      :: binary(),
    to_phase        :: binary(),
    transitioned_at :: integer()
}).

-export_type([phase_transitioned_v1/0]).
-opaque phase_transitioned_v1() :: #phase_transitioned_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> phase_transitioned_v1().
new(#{cartwheel_id := CartwheelId, from_phase := FromPhase, to_phase := ToPhase} = _Params) ->
    #phase_transitioned_v1{
        cartwheel_id = CartwheelId,
        from_phase = FromPhase,
        to_phase = ToPhase,
        transitioned_at = erlang:system_time(millisecond)
    }.

-spec to_map(phase_transitioned_v1()) -> map().
to_map(#phase_transitioned_v1{} = E) ->
    #{
        event_type => <<"phase_transitioned_v1">>,
        cartwheel_id => E#phase_transitioned_v1.cartwheel_id,
        from_phase => E#phase_transitioned_v1.from_phase,
        to_phase => E#phase_transitioned_v1.to_phase,
        transitioned_at => E#phase_transitioned_v1.transitioned_at
    }.

-spec from_map(map()) -> {ok, phase_transitioned_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId, from_phase := FromPhase, to_phase := ToPhase} = Map) ->
    {ok, #phase_transitioned_v1{
        cartwheel_id = CartwheelId,
        from_phase = FromPhase,
        to_phase = ToPhase,
        transitioned_at = maps:get(transitioned_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#phase_transitioned_v1{cartwheel_id = V}) -> V.
get_from_phase(#phase_transitioned_v1{from_phase = V}) -> V.
get_to_phase(#phase_transitioned_v1{to_phase = V}) -> V.
get_transitioned_at(#phase_transitioned_v1{transitioned_at = V}) -> V.
