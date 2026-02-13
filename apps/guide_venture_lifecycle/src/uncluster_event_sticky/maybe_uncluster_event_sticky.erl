%%% @doc maybe_uncluster_event_sticky handler
%%% Business logic for removing an event sticky from its cluster during Big Picture Event Storming.
-module(maybe_uncluster_event_sticky).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case uncluster_event_sticky_v1:validate(Cmd) of
        ok ->
            VentureId = uncluster_event_sticky_v1:get_venture_id(Cmd),
            StickyId = uncluster_event_sticky_v1:get_sticky_id(Cmd),
            EventStickies = maps:get(event_stickies, Context, #{}),
            case maps:find(StickyId, EventStickies) of
                {ok, #{cluster_id := ClusterId}} when ClusterId =/= undefined ->
                    Event = event_sticky_unclustered_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => StickyId,
                        cluster_id => ClusterId
                    }),
                    {ok, [event_sticky_unclustered_v1:to_map(Event)]};
                _ ->
                    {error, sticky_not_in_cluster}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = uncluster_event_sticky_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = uncluster_event_sticky,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = uncluster_event_sticky_v1:to_map(Cmd),
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
