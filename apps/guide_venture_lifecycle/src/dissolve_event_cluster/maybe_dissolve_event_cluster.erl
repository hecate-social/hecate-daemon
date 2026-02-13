%%% @doc maybe_dissolve_event_cluster handler
%%% Business logic for dissolving an event cluster during Big Picture Event Storming.
-module(maybe_dissolve_event_cluster).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case dissolve_event_cluster_v1:validate(Cmd) of
        ok ->
            VentureId = dissolve_event_cluster_v1:get_venture_id(Cmd),
            ClusterId = dissolve_event_cluster_v1:get_cluster_id(Cmd),
            EventClusters = maps:get(event_clusters, Context, #{}),
            case maps:is_key(ClusterId, EventClusters) of
                true ->
                    Event = event_cluster_dissolved_v1:new(#{
                        venture_id => VentureId,
                        cluster_id => ClusterId
                    }),
                    {ok, [event_cluster_dissolved_v1:to_map(Event)]};
                false ->
                    {error, cluster_not_found}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = dissolve_event_cluster_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = dissolve_event_cluster,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = dissolve_event_cluster_v1:to_map(Cmd),
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
