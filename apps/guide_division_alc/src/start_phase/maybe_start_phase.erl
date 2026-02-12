%%% @doc maybe_start_phase handler
%%% Business logic for starting a phase on a division.
-module(maybe_start_phase).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle start_phase_v1 command (business logic only)
-spec handle(start_phase_v1:start_phase_v1()) ->
    {ok, [phase_started_v1:phase_started_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(start_phase_v1:start_phase_v1(), term()) ->
    {ok, [phase_started_v1:phase_started_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    DivisionId = start_phase_v1:get_division_id(Cmd),
    Phase = start_phase_v1:get_phase(Cmd),
    case validate_command(DivisionId, Phase) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(start_phase_v1:start_phase_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    DivisionId = start_phase_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = start_phase,
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = start_phase_v1:to_map(Cmd),
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
    phase_started_v1:new(#{
        division_id => start_phase_v1:get_division_id(Cmd),
        phase => start_phase_v1:get_phase(Cmd)
    }).
