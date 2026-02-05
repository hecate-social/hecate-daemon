%%% @doc complete_testing_v1 command
%%% Completes the testing and implementation phase for a project.
-module(complete_testing_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1]).

-record(complete_testing_v1, {
    project_id :: binary()
}).

-export_type([complete_testing_v1/0]).
-opaque complete_testing_v1() :: #complete_testing_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, complete_testing_v1()} | {error, term()}.
new(#{project_id := ProjectId} = _Params) ->
    Cmd = #complete_testing_v1{
        project_id = ProjectId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(complete_testing_v1()) -> {ok, complete_testing_v1()} | {error, term()}.
validate(#complete_testing_v1{project_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_project_id};
validate(#complete_testing_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(complete_testing_v1()) -> map().
to_map(#complete_testing_v1{} = Cmd) ->
    #{
        command_type => <<"complete_testing">>,
        project_id => Cmd#complete_testing_v1.project_id
    }.

-spec from_map(map()) -> {ok, complete_testing_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#complete_testing_v1{project_id = V}) -> V.
