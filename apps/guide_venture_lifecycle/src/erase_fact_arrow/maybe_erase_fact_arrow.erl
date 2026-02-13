%%% @doc maybe_erase_fact_arrow handler
%%% Business logic for erasing a fact arrow during Big Picture Event Storming.
-module(maybe_erase_fact_arrow).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case erase_fact_arrow_v1:validate(Cmd) of
        ok ->
            Event = fact_arrow_erased_v1:new(#{
                venture_id => erase_fact_arrow_v1:get_venture_id(Cmd),
                arrow_id => erase_fact_arrow_v1:get_arrow_id(Cmd)
            }),
            {ok, [fact_arrow_erased_v1:to_map(Event)]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = erase_fact_arrow_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = erase_fact_arrow,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = erase_fact_arrow_v1:to_map(Cmd),
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
