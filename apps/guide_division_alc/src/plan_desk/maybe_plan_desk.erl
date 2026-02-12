%%% @doc maybe_plan_desk handler
-module(maybe_plan_desk).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, handle/2, dispatch/1]).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case plan_desk_v1:validate(Cmd) of
        {ok, _} ->
            DeskName = plan_desk_v1:get_desk_name(Cmd),
            PlannedDesks = maps:get(planned_desks, Context, #{}),
            case maps:is_key(DeskName, PlannedDesks) of
                true -> {error, desk_already_planned};
                false ->
                    Event = desk_planned_v1:new(#{
                        division_id => plan_desk_v1:get_division_id(Cmd),
                        desk_name => DeskName,
                        description => plan_desk_v1:get_description(Cmd),
                        department => plan_desk_v1:get_department(Cmd),
                        commands => plan_desk_v1:get_commands(Cmd)
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
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = plan_desk_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
