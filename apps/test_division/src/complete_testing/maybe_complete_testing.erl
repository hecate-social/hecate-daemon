-module(maybe_complete_testing).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case complete_testing_v1:validate(Cmd) of
        ok ->
            Event = testing_completed_v1:new(#{
                division_id => complete_testing_v1:get_division_id(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = complete_testing_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = complete_testing,
        aggregate_type = testing_aggregate,
        aggregate_id = DivisionId,
        payload = complete_testing_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => testing_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => test_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
