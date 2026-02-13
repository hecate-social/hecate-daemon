%%% @doc maybe_advance_storm_phase handler
%%% Business logic for advancing the storm phase during Big Picture Event Storming.
%%% Valid transitions: storm -> stack -> groom -> cluster -> name -> map -> promoted
-module(maybe_advance_storm_phase).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, State) ->
    case advance_storm_phase_v1:validate(Cmd) of
        ok ->
            VentureId = advance_storm_phase_v1:get_venture_id(Cmd),
            TargetPhase = advance_storm_phase_v1:get_target_phase(Cmd),
            CurrentPhase = maps:get(storm_phase, State, storm),
            CurrentPhaseBin = atom_to_binary(CurrentPhase, utf8),
            case valid_transition(CurrentPhase, TargetPhase) of
                true ->
                    Event = storm_phase_advanced_v1:new(#{
                        venture_id => VentureId,
                        phase => TargetPhase,
                        previous_phase => CurrentPhaseBin
                    }),
                    {ok, [Event]};
                false ->
                    {error, invalid_phase_transition}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = advance_storm_phase_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = advance_storm_phase,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = advance_storm_phase_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => venture_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% --- Internal ---

valid_transition(storm, <<"stack">>) -> true;
valid_transition(stack, <<"groom">>) -> true;
valid_transition(groom, <<"cluster">>) -> true;
valid_transition(cluster, <<"name">>) -> true;
valid_transition(name, <<"map">>) -> true;
valid_transition(map, <<"promoted">>) -> true;
valid_transition(_, _) -> false.
