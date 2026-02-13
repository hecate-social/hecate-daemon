%%% @doc maybe_pull_event_sticky handler
%%% Business logic for pulling (removing) an event sticky during Big Picture Event Storming.
-module(maybe_pull_event_sticky).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, undefined).

handle(Cmd, _State) ->
    case pull_event_sticky_v1:validate(Cmd) of
        ok ->
            Event = event_sticky_pulled_v1:new(#{
                venture_id => pull_event_sticky_v1:get_venture_id(Cmd),
                sticky_id => pull_event_sticky_v1:get_sticky_id(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = pull_event_sticky_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = pull_event_sticky,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = pull_event_sticky_v1:to_map(Cmd),
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
