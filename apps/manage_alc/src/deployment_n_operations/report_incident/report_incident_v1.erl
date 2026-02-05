%%% @doc report_incident_v1 command
%%% Reports an incident for a project during deployment and operations.
-module(report_incident_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1, get_incident_id/1, get_severity/1, get_description/1]).

-record(report_incident_v1, {
    project_id  :: binary(),
    incident_id :: binary(),
    severity    :: binary(),
    description :: binary()
}).

-export_type([report_incident_v1/0]).
-opaque report_incident_v1() :: #report_incident_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, report_incident_v1()} | {error, term()}.
new(#{project_id := ProjectId} = Params) ->
    Cmd = #report_incident_v1{
        project_id = ProjectId,
        incident_id = maps:get(incident_id, Params, generate_id()),
        severity = maps:get(severity, Params, <<"medium">>),
        description = maps:get(description, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(report_incident_v1()) -> {ok, report_incident_v1()} | {error, term()}.
validate(#report_incident_v1{project_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_project_id};
validate(#report_incident_v1{severity = S}) when
    S =/= <<"low">>, S =/= <<"medium">>, S =/= <<"high">>, S =/= <<"critical">> ->
    {error, invalid_severity};
validate(#report_incident_v1{description = D}) when
    not is_binary(D); byte_size(D) =:= 0 ->
    {error, invalid_description};
validate(#report_incident_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(report_incident_v1()) -> map().
to_map(#report_incident_v1{} = Cmd) ->
    #{
        command_type => <<"report_incident">>,
        project_id => Cmd#report_incident_v1.project_id,
        incident_id => Cmd#report_incident_v1.incident_id,
        severity => Cmd#report_incident_v1.severity,
        description => Cmd#report_incident_v1.description
    }.

-spec from_map(map()) -> {ok, report_incident_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#report_incident_v1{project_id = V}) -> V.
get_incident_id(#report_incident_v1{incident_id = V}) -> V.
get_severity(#report_incident_v1{severity = V}) -> V.
get_description(#report_incident_v1{description = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"inc-", Ts/binary, "-", Rand/binary>>.
