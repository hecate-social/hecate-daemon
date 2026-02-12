%%% @doc maybe_design_event handler
%%% Business logic for designing events within a division.
-module(maybe_design_event).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case design_event_v1:validate(Cmd) of
        {ok, _} ->
            EventName = design_event_v1:get_event_name(Cmd),
            DesignedEvents = maps:get(designed_events, Context, #{}),
            case maps:is_key(EventName, DesignedEvents) of
                true ->
                    {error, event_already_designed};
                false ->
                    Event = event_designed_v1:new(#{
                        division_id => design_event_v1:get_division_id(Cmd),
                        event_name => EventName,
                        description => design_event_v1:get_description(Cmd),
                        aggregate_name => design_event_v1:get_aggregate_name(Cmd),
                        fields => design_event_v1:get_fields(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = design_event_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = design_event,
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = design_event_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
