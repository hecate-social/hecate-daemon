%%% @doc maybe_name_event_cluster handler
%%% Business logic for naming an event cluster during Big Picture Event Storming.
-module(maybe_name_event_cluster).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case name_event_cluster_v1:validate(Cmd) of
        ok ->
            VentureId = name_event_cluster_v1:get_venture_id(Cmd),
            ClusterId = name_event_cluster_v1:get_cluster_id(Cmd),
            Name = name_event_cluster_v1:get_name(Cmd),
            EventClusters = maps:get(event_clusters, Context, #{}),
            case maps:is_key(ClusterId, EventClusters) of
                true ->
                    Event = event_cluster_named_v1:new(#{
                        venture_id => VentureId,
                        cluster_id => ClusterId,
                        name => Name
                    }),
                    {ok, [event_cluster_named_v1:to_map(Event)]};
                false ->
                    {error, cluster_not_found}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = name_event_cluster_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = name_event_cluster,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = name_event_cluster_v1:to_map(Cmd),
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
