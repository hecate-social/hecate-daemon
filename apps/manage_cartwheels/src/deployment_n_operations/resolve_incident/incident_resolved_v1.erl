%%% @doc incident_resolved_v1 event
%%% Emitted when an incident is resolved for a project.
-module(incident_resolved_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_incident_id/1, get_resolution/1, get_resolved_at/1]).

-record(incident_resolved_v1, {
    cartwheel_id  :: binary(),
    incident_id :: binary(),
    resolution  :: binary(),
    resolved_at :: integer()
}).

-export_type([incident_resolved_v1/0]).
-opaque incident_resolved_v1() :: #incident_resolved_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> incident_resolved_v1().
new(#{cartwheel_id := CartwheelId, incident_id := IncidentId,
      resolution := Resolution} = _Params) ->
    #incident_resolved_v1{
        cartwheel_id = CartwheelId,
        incident_id = IncidentId,
        resolution = Resolution,
        resolved_at = erlang:system_time(millisecond)
    }.

-spec to_map(incident_resolved_v1()) -> map().
to_map(#incident_resolved_v1{} = E) ->
    #{
        event_type => <<"incident_resolved_v1">>,
        cartwheel_id => E#incident_resolved_v1.cartwheel_id,
        incident_id => E#incident_resolved_v1.incident_id,
        resolution => E#incident_resolved_v1.resolution,
        resolved_at => E#incident_resolved_v1.resolved_at
    }.

-spec from_map(map()) -> {ok, incident_resolved_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId, incident_id := IncidentId,
           resolution := Resolution} = Map) ->
    {ok, #incident_resolved_v1{
        cartwheel_id = CartwheelId,
        incident_id = IncidentId,
        resolution = Resolution,
        resolved_at = maps:get(resolved_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#incident_resolved_v1{cartwheel_id = V}) -> V.
get_incident_id(#incident_resolved_v1{incident_id = V}) -> V.
get_resolution(#incident_resolved_v1{resolution = V}) -> V.
get_resolved_at(#incident_resolved_v1{resolved_at = V}) -> V.
