%%% @doc initiate_project_v1 command
%%% Initiates a new project in the ALC domain.
-module(initiate_project_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1, get_name/1, get_description/1]).

-record(initiate_project_v1, {
    project_id  :: binary(),
    name        :: binary(),
    description :: binary() | undefined
}).

-export_type([initiate_project_v1/0]).
-opaque initiate_project_v1() :: #initiate_project_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_project_v1()} | {error, term()}.
new(#{name := Name} = Params) ->
    ProjectId = maps:get(project_id, Params, generate_id()),
    Cmd = #initiate_project_v1{
        project_id = ProjectId,
        name = Name,
        description = maps:get(description, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_project_v1()) -> {ok, initiate_project_v1()} | {error, term()}.
validate(#initiate_project_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#initiate_project_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_project_v1()) -> map().
to_map(#initiate_project_v1{} = Cmd) ->
    #{
        command_type => <<"initiate_project">>,
        project_id => Cmd#initiate_project_v1.project_id,
        name => Cmd#initiate_project_v1.name,
        description => Cmd#initiate_project_v1.description
    }.

-spec from_map(map()) -> {ok, initiate_project_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#initiate_project_v1{project_id = V}) -> V.
get_name(#initiate_project_v1{name = V}) -> V.
get_description(#initiate_project_v1{description = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"prj-", Ts/binary, "-", Rand/binary>>.
