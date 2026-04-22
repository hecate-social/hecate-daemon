%%% @doc Announces this node's site membership to the Macula mesh.
%%%
%%% Publishes a FACT to {realm}.hecate.site.node_joined so other nodes
%%% in the same site can auto-admit this node.
%%%
%%% Re-announces periodically (every 60s) so nodes that boot later
%%% or miss the initial announcement still discover this node.
%%% @end
-module(announce_site_node).

-export([announce/0, start_periodic/0]).

-define(RE_ANNOUNCE_INTERVAL, 60_000).

-spec announce() -> ok | {error, term()}.
announce() ->
    case hecate_mesh:is_connected() of
        false ->
            {error, mesh_not_connected};
        true ->
            do_announce()
    end.

%% @doc Start periodic re-announcement.
%% Spawns a process that re-announces every 60 seconds so
%% late-joining nodes discover us.
-spec start_periodic() -> pid().
start_periodic() ->
    spawn_link(fun periodic_loop/0).

periodic_loop() ->
    timer:sleep(?RE_ANNOUNCE_INTERVAL),
    _ = announce(),
    periodic_loop().

do_announce() ->
    Topic = hecate_topics:app_fact(<<"site">>, <<"node_announced">>, 1),
    SiteId = guide_site_lifecycle_app:site_id(),
    NodeName = atom_to_binary(node()),

    Fact = #{
        site_id => SiteId,
        node_name => NodeName,
        timestamp => erlang:system_time(millisecond)
    },

    case hecate_mesh:publish(Topic, Fact) of
        ok ->
            logger:info("[site] Announced node to mesh: ~s (site ~s)", [NodeName, SiteId]),
            ok;
        {error, Reason} ->
            logger:warning("[site] Failed to announce node to mesh: ~p", [Reason]),
            {error, Reason}
    end.
