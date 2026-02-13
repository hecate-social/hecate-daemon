%%% @doc maybe_promote_event_cluster handler
%%% Business logic for promoting an event cluster to a division.
%%% Emits BOTH event_cluster_promoted_v1 AND division_identified_v1 (reusing existing module).
%%% This bridges Big Picture Event Storming into the venture lifecycle.
-module(maybe_promote_event_cluster).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case promote_event_cluster_v1:validate(Cmd) of
        ok ->
            VentureId = promote_event_cluster_v1:get_venture_id(Cmd),
            ClusterId = promote_event_cluster_v1:get_cluster_id(Cmd),
            EventClusters = maps:get(event_clusters, Context, #{}),
            case maps:find(ClusterId, EventClusters) of
                {ok, ClusterInfo} ->
                    ClusterName = maps:get(name, ClusterInfo, <<"Unnamed Cluster">>),
                    %% Emit event_cluster_promoted_v1
                    PromotedEvent = event_cluster_promoted_v1:new(#{
                        venture_id => VentureId,
                        cluster_id => ClusterId
                    }),
                    DivisionId = event_cluster_promoted_v1:get_division_id(PromotedEvent),
                    PromotedMap = event_cluster_promoted_v1:to_map(PromotedEvent),
                    %% Reuse existing division_identified_v1 event module
                    DivEvent = division_identified_v1:new(#{
                        venture_id => VentureId,
                        division_id => DivisionId,
                        context_name => ClusterName,
                        description => <<"Promoted from Big Picture Event Storm">>,
                        identified_by => <<"storm">>
                    }),
                    DivisionMap = division_identified_v1:to_map(DivEvent),
                    {ok, [PromotedMap, DivisionMap]};
                error ->
                    {error, cluster_not_found}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = promote_event_cluster_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = promote_event_cluster,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = promote_event_cluster_v1:to_map(Cmd),
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
