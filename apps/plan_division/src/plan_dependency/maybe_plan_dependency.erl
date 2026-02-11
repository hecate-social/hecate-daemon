-module(maybe_plan_dependency).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case plan_dependency_v1:validate(Cmd) of
        ok ->
            Event = dependency_planned_v1:new(#{
                division_id => plan_dependency_v1:get_division_id(Cmd),
                from_desk => plan_dependency_v1:get_from_desk(Cmd),
                to_desk => plan_dependency_v1:get_to_desk(Cmd),
                dependency_type => plan_dependency_v1:get_dependency_type(Cmd),
                description => plan_dependency_v1:get_description(Cmd),
                planned_by => plan_dependency_v1:get_planned_by(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = plan_dependency_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = plan_dependency,
        aggregate_type = plan_aggregate,
        aggregate_id = DivisionId,
        payload = plan_dependency_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => plan_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => plan_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
