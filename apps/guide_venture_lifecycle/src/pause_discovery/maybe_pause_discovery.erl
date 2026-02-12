%%% @doc maybe_pause_discovery handler
%%% Business logic for pausing the discovery phase.
-module(maybe_pause_discovery).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case pause_discovery_v1:validate(Cmd) of
        ok ->
            Event = discovery_paused_v1:new(#{
                venture_id => pause_discovery_v1:get_venture_id(Cmd),
                reason => pause_discovery_v1:get_reason(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = pause_discovery_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = pause_discovery,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = pause_discovery_v1:to_map(Cmd),
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
