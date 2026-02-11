-module(maybe_plan_desk).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case plan_desk_v1:validate(Cmd) of
        ok ->
            DeskName = plan_desk_v1:get_desk_name(Cmd),
            PlannedDesks = maps:get(planned_desks, Context, #{}),
            case maps:is_key(DeskName, PlannedDesks) of
                true ->
                    {error, desk_already_planned};
                false ->
                    Event = desk_planned_v1:new(#{
                        division_id => plan_desk_v1:get_division_id(Cmd),
                        desk_name => DeskName,
                        department => plan_desk_v1:get_department(Cmd),
                        aggregate_name => plan_desk_v1:get_aggregate_name(Cmd),
                        description => plan_desk_v1:get_description(Cmd),
                        priority => plan_desk_v1:get_priority(Cmd),
                        planned_by => plan_desk_v1:get_planned_by(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = plan_desk_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = plan_desk,
        aggregate_type = plan_aggregate,
        aggregate_id = DivisionId,
        payload = plan_desk_v1:to_map(Cmd),
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
