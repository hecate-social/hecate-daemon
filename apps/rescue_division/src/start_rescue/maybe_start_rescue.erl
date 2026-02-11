-module(maybe_start_rescue).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case start_rescue_v1:validate(Cmd) of
        ok ->
            Event = rescue_started_v1:new(#{
                division_id => start_rescue_v1:get_division_id(Cmd),
                incident_id => start_rescue_v1:get_incident_id(Cmd),
                started_by => start_rescue_v1:get_started_by(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = start_rescue_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = start_rescue,
        aggregate_type = rescue_aggregate,
        aggregate_id = DivisionId,
        payload = start_rescue_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => rescue_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => rescue_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
