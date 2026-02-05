%%% @doc deployment_recorded_v1 event
%%% Emitted when a deployment is recorded for a project.
-module(deployment_recorded_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_deployment_id/1, get_environment/1, get_version/1, get_notes/1, get_deployed_at/1]).

-record(deployment_recorded_v1, {
    project_id    :: binary(),
    deployment_id :: binary(),
    environment   :: binary(),
    version       :: binary(),
    notes         :: binary() | undefined,
    deployed_at   :: integer()
}).

-export_type([deployment_recorded_v1/0]).
-opaque deployment_recorded_v1() :: #deployment_recorded_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> deployment_recorded_v1().
new(#{project_id := ProjectId, deployment_id := DeploymentId,
      environment := Environment, version := Version} = Params) ->
    #deployment_recorded_v1{
        project_id = ProjectId,
        deployment_id = DeploymentId,
        environment = Environment,
        version = Version,
        notes = maps:get(notes, Params, undefined),
        deployed_at = erlang:system_time(millisecond)
    }.

-spec to_map(deployment_recorded_v1()) -> map().
to_map(#deployment_recorded_v1{} = E) ->
    #{
        event_type => <<"deployment_recorded_v1">>,
        project_id => E#deployment_recorded_v1.project_id,
        deployment_id => E#deployment_recorded_v1.deployment_id,
        environment => E#deployment_recorded_v1.environment,
        version => E#deployment_recorded_v1.version,
        notes => E#deployment_recorded_v1.notes,
        deployed_at => E#deployment_recorded_v1.deployed_at
    }.

-spec from_map(map()) -> {ok, deployment_recorded_v1()} | {error, term()}.
from_map(#{project_id := ProjectId, deployment_id := DeploymentId,
           environment := Environment, version := Version} = Map) ->
    {ok, #deployment_recorded_v1{
        project_id = ProjectId,
        deployment_id = DeploymentId,
        environment = Environment,
        version = Version,
        notes = maps:get(notes, Map, undefined),
        deployed_at = maps:get(deployed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#deployment_recorded_v1{project_id = V}) -> V.
get_deployment_id(#deployment_recorded_v1{deployment_id = V}) -> V.
get_environment(#deployment_recorded_v1{environment = V}) -> V.
get_version(#deployment_recorded_v1{version = V}) -> V.
get_notes(#deployment_recorded_v1{notes = V}) -> V.
get_deployed_at(#deployment_recorded_v1{deployed_at = V}) -> V.
