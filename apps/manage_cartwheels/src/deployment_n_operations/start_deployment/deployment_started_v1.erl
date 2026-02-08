%%% @doc deployment_started_v1 event
%%% Emitted when the deployment and operations phase starts.
-module(deployment_started_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_started_at/1]).

-record(deployment_started_v1, {
    cartwheel_id :: binary(),
    started_at :: integer()
}).

-export_type([deployment_started_v1/0]).
-opaque deployment_started_v1() :: #deployment_started_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> deployment_started_v1().
new(#{cartwheel_id := CartwheelId} = _Params) ->
    #deployment_started_v1{
        cartwheel_id = CartwheelId,
        started_at = erlang:system_time(millisecond)
    }.

-spec to_map(deployment_started_v1()) -> map().
to_map(#deployment_started_v1{} = E) ->
    #{
        event_type => <<"deployment_started_v1">>,
        cartwheel_id => E#deployment_started_v1.cartwheel_id,
        started_at => E#deployment_started_v1.started_at
    }.

-spec from_map(map()) -> {ok, deployment_started_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId} = Map) ->
    {ok, #deployment_started_v1{
        cartwheel_id = CartwheelId,
        started_at = maps:get(started_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#deployment_started_v1{cartwheel_id = V}) -> V.
get_started_at(#deployment_started_v1{started_at = V}) -> V.
