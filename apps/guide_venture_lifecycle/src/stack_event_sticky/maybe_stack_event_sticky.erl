%%% @doc maybe_stack_event_sticky handler
%%% Business logic for stacking an event sticky during Big Picture Event Storming.
%%% This is a multi-event handler: it may emit event_stack_emerged_v1 + event_sticky_stacked_v1.
-module(maybe_stack_event_sticky).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, State) ->
    case stack_event_sticky_v1:validate(Cmd) of
        ok ->
            VentureId = stack_event_sticky_v1:get_venture_id(Cmd),
            StickyId = stack_event_sticky_v1:get_sticky_id(Cmd),
            TargetStickyId = stack_event_sticky_v1:get_target_sticky_id(Cmd),
            EventStickies = maps:get(event_stickies, State, #{}),
            %% Check if target sticky is already in a stack
            TargetStackId = case maps:find(TargetStickyId, EventStickies) of
                {ok, #{stack_id := Sid}} when Sid =/= undefined -> Sid;
                _ -> undefined
            end,
            case TargetStackId of
                undefined ->
                    %% Target not in a stack: emerge a new stack, then stack both stickies
                    EmergedEvt = event_stack_emerged_v1:new(#{
                        venture_id => VentureId,
                        sticky_ids => [TargetStickyId, StickyId]
                    }),
                    NewStackId = event_stack_emerged_v1:get_stack_id(EmergedEvt),
                    TargetStackedEvt = event_sticky_stacked_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => TargetStickyId,
                        stack_id => NewStackId
                    }),
                    SourceStackedEvt = event_sticky_stacked_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => StickyId,
                        stack_id => NewStackId
                    }),
                    {ok, [
                        event_stack_emerged_v1:to_map(EmergedEvt),
                        event_sticky_stacked_v1:to_map(TargetStackedEvt),
                        event_sticky_stacked_v1:to_map(SourceStackedEvt)
                    ]};
                ExistingStackId ->
                    %% Target already in a stack: just stack the source onto it
                    SourceStackedEvt = event_sticky_stacked_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => StickyId,
                        stack_id => ExistingStackId
                    }),
                    {ok, [event_sticky_stacked_v1:to_map(SourceStackedEvt)]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = stack_event_sticky_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = stack_event_sticky,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = stack_event_sticky_v1:to_map(Cmd),
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
