%%% @doc record_deployment_v1 command
%%% Records a deployment for a project in a specific environment.
-module(record_deployment_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1, get_deployment_id/1, get_environment/1, get_version/1, get_notes/1]).

-record(record_deployment_v1, {
    project_id    :: binary(),
    deployment_id :: binary(),
    environment   :: binary(),
    version       :: binary(),
    notes         :: binary() | undefined
}).

-export_type([record_deployment_v1/0]).
-opaque record_deployment_v1() :: #record_deployment_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, record_deployment_v1()} | {error, term()}.
new(#{project_id := ProjectId} = Params) ->
    Cmd = #record_deployment_v1{
        project_id = ProjectId,
        deployment_id = maps:get(deployment_id, Params, generate_id()),
        environment = maps:get(environment, Params, undefined),
        version = maps:get(version, Params, undefined),
        notes = maps:get(notes, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(record_deployment_v1()) -> {ok, record_deployment_v1()} | {error, term()}.
validate(#record_deployment_v1{project_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_project_id};
validate(#record_deployment_v1{environment = E}) when
    not is_binary(E); byte_size(E) =:= 0 ->
    {error, invalid_environment};
validate(#record_deployment_v1{version = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_version};
validate(#record_deployment_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(record_deployment_v1()) -> map().
to_map(#record_deployment_v1{} = Cmd) ->
    #{
        command_type => <<"record_deployment">>,
        project_id => Cmd#record_deployment_v1.project_id,
        deployment_id => Cmd#record_deployment_v1.deployment_id,
        environment => Cmd#record_deployment_v1.environment,
        version => Cmd#record_deployment_v1.version,
        notes => Cmd#record_deployment_v1.notes
    }.

-spec from_map(map()) -> {ok, record_deployment_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#record_deployment_v1{project_id = V}) -> V.
get_deployment_id(#record_deployment_v1{deployment_id = V}) -> V.
get_environment(#record_deployment_v1{environment = V}) -> V.
get_version(#record_deployment_v1{version = V}) -> V.
get_notes(#record_deployment_v1{notes = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"dep-", Ts/binary, "-", Rand/binary>>.
