-module(maybe_raise_incident).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case raise_incident_v1:validate(Cmd) of
        ok ->
            Event = incident_raised_v1:new(#{
                division_id => raise_incident_v1:get_division_id(Cmd),
                incident_title => raise_incident_v1:get_incident_title(Cmd),
                severity => raise_incident_v1:get_severity(Cmd),
                description => raise_incident_v1:get_description(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = raise_incident_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = raise_incident,
        aggregate_type = monitoring_aggregate,
        aggregate_id = DivisionId,
        payload = raise_incident_v1:to_map(Cmd),
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
