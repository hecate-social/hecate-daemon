%%% @doc incident_reported_v1 event
%%% Emitted when an incident is reported for a project.
-module(incident_reported_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_incident_id/1, get_severity/1, get_description/1, get_reported_at/1]).

-record(incident_reported_v1, {
    project_id  :: binary(),
    incident_id :: binary(),
    severity    :: binary(),
    description :: binary(),
    reported_at :: integer()
}).

-export_type([incident_reported_v1/0]).
-opaque incident_reported_v1() :: #incident_reported_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> incident_reported_v1().
new(#{project_id := ProjectId, incident_id := IncidentId,
      severity := Severity, description := Description} = _Params) ->
    #incident_reported_v1{
        project_id = ProjectId,
        incident_id = IncidentId,
        severity = Severity,
        description = Description,
        reported_at = erlang:system_time(millisecond)
    }.

-spec to_map(incident_reported_v1()) -> map().
to_map(#incident_reported_v1{} = E) ->
    #{
        event_type => <<"incident_reported_v1">>,
        project_id => E#incident_reported_v1.project_id,
        incident_id => E#incident_reported_v1.incident_id,
        severity => E#incident_reported_v1.severity,
        description => E#incident_reported_v1.description,
        reported_at => E#incident_reported_v1.reported_at
    }.

-spec from_map(map()) -> {ok, incident_reported_v1()} | {error, term()}.
from_map(#{project_id := ProjectId, incident_id := IncidentId,
           severity := Severity, description := Description} = Map) ->
    {ok, #incident_reported_v1{
        project_id = ProjectId,
        incident_id = IncidentId,
        severity = Severity,
        description = Description,
        reported_at = maps:get(reported_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#incident_reported_v1{project_id = V}) -> V.
get_incident_id(#incident_reported_v1{incident_id = V}) -> V.
get_severity(#incident_reported_v1{severity = V}) -> V.
get_description(#incident_reported_v1{description = V}) -> V.
get_reported_at(#incident_reported_v1{reported_at = V}) -> V.
