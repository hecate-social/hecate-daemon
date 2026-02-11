-module(maybe_complete_discovery).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case complete_discovery_v1:validate(Cmd) of
        ok ->
            Event = discovery_completed_v1:new(#{
                venture_id => complete_discovery_v1:get_venture_id(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = complete_discovery_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = complete_discovery,
        aggregate_type = discovery_aggregate,
        aggregate_id = VentureId,
        payload = complete_discovery_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => discovery_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => discover_divisions_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
