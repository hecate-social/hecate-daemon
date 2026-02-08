%%% @doc discovery_started_v1 event
%%% Emitted when the discovery phase is started for a project.
-module(discovery_started_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_started_at/1]).

-record(discovery_started_v1, {
    cartwheel_id :: binary(),
    started_at :: integer()
}).

-export_type([discovery_started_v1/0]).
-opaque discovery_started_v1() :: #discovery_started_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> discovery_started_v1().
new(#{cartwheel_id := CartwheelId} = _Params) ->
    #discovery_started_v1{
        cartwheel_id = CartwheelId,
        started_at = erlang:system_time(millisecond)
    }.

-spec to_map(discovery_started_v1()) -> map().
to_map(#discovery_started_v1{} = E) ->
    #{
        event_type => <<"discovery_started_v1">>,
        cartwheel_id => E#discovery_started_v1.cartwheel_id,
        started_at => E#discovery_started_v1.started_at
    }.

-spec from_map(map()) -> {ok, discovery_started_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId} = Map) ->
    {ok, #discovery_started_v1{
        cartwheel_id = CartwheelId,
        started_at = maps:get(started_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#discovery_started_v1{cartwheel_id = V}) -> V.
get_started_at(#discovery_started_v1{started_at = V}) -> V.
