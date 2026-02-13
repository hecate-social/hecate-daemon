%%% @doc maybe_cluster_event_sticky handler
%%% Business logic for clustering event stickies during Big Picture Event Storming.
%%% If target_cluster_id matches an existing cluster, the sticky joins it.
%%% If target_cluster_id matches another sticky (not yet clustered), a new cluster emerges.
-module(maybe_cluster_event_sticky).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case cluster_event_sticky_v1:validate(Cmd) of
        ok ->
            VentureId = cluster_event_sticky_v1:get_venture_id(Cmd),
            StickyId = cluster_event_sticky_v1:get_sticky_id(Cmd),
            TargetClusterId = cluster_event_sticky_v1:get_target_cluster_id(Cmd),
            EventClusters = maps:get(event_clusters, Context, #{}),
            case maps:is_key(TargetClusterId, EventClusters) of
                true ->
                    %% Target is an existing cluster — just add the sticky
                    Event = event_sticky_clustered_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => StickyId,
                        cluster_id => TargetClusterId
                    }),
                    {ok, [event_sticky_clustered_v1:to_map(Event)]};
                false ->
                    %% Target is another sticky — a new cluster emerges
                    ClusterEmerged = event_cluster_emerged_v1:new(#{
                        venture_id => VentureId,
                        sticky_ids => [StickyId, TargetClusterId]
                    }),
                    ClusterId = event_cluster_emerged_v1:get_cluster_id(ClusterEmerged),
                    Clustered1 = event_sticky_clustered_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => StickyId,
                        cluster_id => ClusterId
                    }),
                    Clustered2 = event_sticky_clustered_v1:new(#{
                        venture_id => VentureId,
                        sticky_id => TargetClusterId,
                        cluster_id => ClusterId
                    }),
                    {ok, [
                        event_cluster_emerged_v1:to_map(ClusterEmerged),
                        event_sticky_clustered_v1:to_map(Clustered1),
                        event_sticky_clustered_v1:to_map(Clustered2)
                    ]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = cluster_event_sticky_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = cluster_event_sticky,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = cluster_event_sticky_v1:to_map(Cmd),
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
