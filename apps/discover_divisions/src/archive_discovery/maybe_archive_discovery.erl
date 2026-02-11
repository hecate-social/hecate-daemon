-module(maybe_archive_discovery).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case archive_discovery_v1:validate(Cmd) of
        ok ->
            Event = discovery_archived_v1:new(#{
                venture_id => archive_discovery_v1:get_venture_id(Cmd),
                archived_by => archive_discovery_v1:get_archived_by(Cmd),
                reason => archive_discovery_v1:get_reason(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = archive_discovery_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = archive_discovery,
        aggregate_type = discovery_aggregate,
        aggregate_id = VentureId,
        payload = archive_discovery_v1:to_map(Cmd),
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
