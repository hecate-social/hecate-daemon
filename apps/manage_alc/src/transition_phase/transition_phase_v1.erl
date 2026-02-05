%%% @doc transition_phase_v1 command
%%% Transitions the project from one ALC phase to another.
-module(transition_phase_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1, get_from_phase/1, get_to_phase/1]).

-record(transition_phase_v1, {
    project_id :: binary(),
    from_phase :: binary(),
    to_phase   :: binary()
}).

-export_type([transition_phase_v1/0]).
-opaque transition_phase_v1() :: #transition_phase_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, transition_phase_v1()} | {error, term()}.
new(#{project_id := ProjectId, from_phase := FromPhase, to_phase := ToPhase} = _Params) ->
    Cmd = #transition_phase_v1{
        project_id = ProjectId,
        from_phase = FromPhase,
        to_phase = ToPhase
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(transition_phase_v1()) -> {ok, transition_phase_v1()} | {error, term()}.
validate(#transition_phase_v1{project_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_project_id};
validate(#transition_phase_v1{from_phase = F}) when
    F =/= <<"discovery_n_analysis">>, F =/= <<"architecture_n_planning">>,
    F =/= <<"testing_n_implementation">>, F =/= <<"deployment_n_operations">> ->
    {error, invalid_from_phase};
validate(#transition_phase_v1{to_phase = T}) when
    T =/= <<"discovery_n_analysis">>, T =/= <<"architecture_n_planning">>,
    T =/= <<"testing_n_implementation">>, T =/= <<"deployment_n_operations">> ->
    {error, invalid_to_phase};
validate(#transition_phase_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(transition_phase_v1()) -> map().
to_map(#transition_phase_v1{} = Cmd) ->
    #{
        command_type => <<"transition_phase">>,
        project_id => Cmd#transition_phase_v1.project_id,
        from_phase => Cmd#transition_phase_v1.from_phase,
        to_phase => Cmd#transition_phase_v1.to_phase
    }.

-spec from_map(map()) -> {ok, transition_phase_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#transition_phase_v1{project_id = V}) -> V.
get_from_phase(#transition_phase_v1{from_phase = V}) -> V.
get_to_phase(#transition_phase_v1{to_phase = V}) -> V.
