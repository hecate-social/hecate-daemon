%%% @doc maybe_groom_event_stack handler
%%% Business logic for grooming a stack during Big Picture Event Storming.
%%% Picks a canonical sticky, absorbs the rest, canonical gets weight = stack size.
-module(maybe_groom_event_stack).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, State) ->
    case groom_event_stack_v1:validate(Cmd) of
        ok ->
            VentureId = groom_event_stack_v1:get_venture_id(Cmd),
            StackId = groom_event_stack_v1:get_stack_id(Cmd),
            CanonicalStickyId = groom_event_stack_v1:get_canonical_sticky_id(Cmd),
            EventStacks = maps:get(event_stacks, State, #{}),
            case maps:find(StackId, EventStacks) of
                {ok, #{sticky_ids := StickyIds}} ->
                    case lists:member(CanonicalStickyId, StickyIds) of
                        true ->
                            Weight = length(StickyIds),
                            AbsorbedIds = lists:delete(CanonicalStickyId, StickyIds),
                            Event = event_stack_groomed_v1:new(#{
                                venture_id => VentureId,
                                stack_id => StackId,
                                canonical_sticky_id => CanonicalStickyId,
                                weight => Weight,
                                absorbed_sticky_ids => AbsorbedIds
                            }),
                            {ok, [Event]};
                        false ->
                            {error, canonical_sticky_not_in_stack}
                    end;
                error ->
                    {error, stack_not_found}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = groom_event_stack_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = groom_event_stack,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = groom_event_stack_v1:to_map(Cmd),
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
