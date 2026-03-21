%%% @doc Announces this node's site membership to the Macula mesh.
%%%
%%% Publishes a FACT to {realm}.hecate.site.node_joined so other nodes
%%% in the same site can auto-admit this node.
%%%
%%% Called once after site auto-init + auto-admit completes.
%%% @end
-module(announce_site_node).

-export([announce/0]).

-spec announce() -> ok | {error, term()}.
announce() ->
    case hecate_mesh:is_connected() of
        false ->
            {error, mesh_not_connected};
        true ->
            do_announce()
    end.

do_announce() ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Topic = <<Realm/binary, ".hecate.site.node_joined">>,
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
