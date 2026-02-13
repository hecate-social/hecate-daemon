%%% @doc maybe_unstack_event_sticky handler
%%% Business logic for removing an event sticky from its stack during Big Picture Event Storming.
-module(maybe_unstack_event_sticky).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, State) ->
    case unstack_event_sticky_v1:validate(Cmd) of
        ok ->
            VentureId = unstack_event_sticky_v1:get_venture_id(Cmd),
            StickyId = unstack_event_sticky_v1:get_sticky_id(Cmd),
            EventStickies = maps:get(event_stickies, State, #{}),
            %% Look up the sticky's current stack_id
            StackId = case maps:find(StickyId, EventStickies) of
                {ok, #{stack_id := Sid}} when Sid =/= undefined -> Sid;
                _ -> undefined
            end,
            case StackId of
                undefined ->
                    {error, sticky_not_in_stack};
                _ ->
                    Event = event_sticky_unstacked_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => StickyId,
                        stack_id => StackId
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = unstack_event_sticky_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = unstack_event_sticky,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = unstack_event_sticky_v1:to_map(Cmd),
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
