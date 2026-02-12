%%% @doc maybe_resume_phase handler
%%% Business logic for resuming a paused phase on a division.
-module(maybe_resume_phase).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) ->
    handle(Cmd, undefined).

handle(Cmd, _State) ->
    DivisionId = resume_phase_v1:get_division_id(Cmd),
    Phase = resume_phase_v1:get_phase(Cmd),
    case validate_command(DivisionId, Phase) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

dispatch(Cmd) ->
    DivisionId = resume_phase_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = resume_phase,
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = resume_phase_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(DivisionId, Phase) when
    is_binary(DivisionId), byte_size(DivisionId) > 0,
    is_binary(Phase), byte_size(Phase) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    phase_resumed_v1:new(#{
        division_id => resume_phase_v1:get_division_id(Cmd),
        phase => resume_phase_v1:get_phase(Cmd)
    }).
