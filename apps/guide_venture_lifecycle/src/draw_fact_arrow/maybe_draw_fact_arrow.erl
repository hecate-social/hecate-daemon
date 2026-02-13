%%% @doc maybe_draw_fact_arrow handler
%%% Business logic for drawing a fact arrow between clusters during Big Picture Event Storming.
-module(maybe_draw_fact_arrow).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case draw_fact_arrow_v1:validate(Cmd) of
        ok ->
            Event = fact_arrow_drawn_v1:new(#{
                venture_id => draw_fact_arrow_v1:get_venture_id(Cmd),
                from_cluster => draw_fact_arrow_v1:get_from_cluster(Cmd),
                to_cluster => draw_fact_arrow_v1:get_to_cluster(Cmd),
                fact_name => draw_fact_arrow_v1:get_fact_name(Cmd)
            }),
            {ok, [fact_arrow_drawn_v1:to_map(Event)]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = draw_fact_arrow_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = draw_fact_arrow,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = draw_fact_arrow_v1:to_map(Cmd),
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
