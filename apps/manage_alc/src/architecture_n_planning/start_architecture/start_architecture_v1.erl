%%% @doc start_architecture_v1 command
%%% Starts the architecture and planning phase for an ALC project.
-module(start_architecture_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1]).

-record(start_architecture_v1, {
    project_id :: binary()
}).

-export_type([start_architecture_v1/0]).
-opaque start_architecture_v1() :: #start_architecture_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, start_architecture_v1()} | {error, term()}.
new(#{project_id := ProjectId} = _Params) ->
    Cmd = #start_architecture_v1{
        project_id = ProjectId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(start_architecture_v1()) -> {ok, start_architecture_v1()} | {error, term()}.
validate(#start_architecture_v1{project_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_project_id};
validate(#start_architecture_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(start_architecture_v1()) -> map().
to_map(#start_architecture_v1{} = Cmd) ->
    #{
        command_type => <<"start_architecture">>,
        project_id => Cmd#start_architecture_v1.project_id
    }.

-spec from_map(map()) -> {ok, start_architecture_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#start_architecture_v1{project_id = V}) -> V.
