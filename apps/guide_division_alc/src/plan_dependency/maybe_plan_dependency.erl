%%% @doc maybe_plan_dependency handler
-module(maybe_plan_dependency).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, handle/2, dispatch/1]).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case plan_dependency_v1:validate(Cmd) of
        {ok, _} ->
            DepId = plan_dependency_v1:get_dependency_id(Cmd),
            PlannedDeps = maps:get(planned_dependencies, Context, #{}),
            case maps:is_key(DepId, PlannedDeps) of
                true -> {error, dependency_already_planned};
                false ->
                    Event = dependency_planned_v1:new(#{
                        division_id => plan_dependency_v1:get_division_id(Cmd),
                        dependency_id => DepId,
                        from_desk => plan_dependency_v1:get_from_desk(Cmd),
                        to_desk => plan_dependency_v1:get_to_desk(Cmd),
                        dep_type => plan_dependency_v1:get_dep_type(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = plan_dependency_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = plan_dependency,
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = plan_dependency_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
