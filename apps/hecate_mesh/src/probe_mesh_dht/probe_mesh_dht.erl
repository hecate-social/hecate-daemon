%%% @doc Mesh proof probe: pool identity and link health.
%%%
%%% Verifies that this node has a mesh identity and at least a
%%% snapshot of its station-link pool. Zero healthy links is valid
%%% (solo dev node, mesh not yet reachable) — the probe verifies
%%% pool participation, not link count.
%%% @end
-module(probe_mesh_dht).

-export([run/1]).

-spec run(macula:pool()) -> {ok, map()} | {error, term()}.
run(Pool) ->
    case macula:status(Pool) of
        {ok, #{self_node_id := NodeId, healthy_links := Links}} ->
            {ok, #{
                node_id => binary:encode_hex(NodeId),
                peer_count => Links,
                solo_node => Links =:= 0
            }};
        {error, Reason} ->
            {error, {no_status, Reason}}
    end.
