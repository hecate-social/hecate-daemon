-module(maybe_resume_monitoring).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case resume_monitoring_v1:validate(Cmd) of
        ok ->
            Event = monitoring_resumed_v1:new(#{
                division_id => resume_monitoring_v1:get_division_id(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = resume_monitoring_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = resume_monitoring,
        aggregate_type = monitoring_aggregate,
        aggregate_id = DivisionId,
        payload = resume_monitoring_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => monitoring_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => monitor_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
