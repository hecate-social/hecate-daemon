-module(maybe_pause_generation).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case pause_generation_v1:validate(Cmd) of
        ok ->
            Event = generation_paused_v1:new(#{
                division_id => pause_generation_v1:get_division_id(Cmd),
                reason => pause_generation_v1:get_reason(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = pause_generation_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = pause_generation,
        aggregate_type = generation_aggregate,
        aggregate_id = DivisionId,
        payload = pause_generation_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => generation_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => generate_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
