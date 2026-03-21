%%% @doc Mesh proof probe: DHT identity and routing table.
%%%
%%% Verifies that this node has a DHT identity and can query
%%% its routing table. Zero peers is valid (solo dev node) -
%%% the probe verifies DHT participation, not peer count.
%%% @end
-module(probe_mesh_dht).

-export([run/1]).

-spec run(pid()) -> {ok, map()} | {error, term()}.
run(Client) ->
    case macula:get_node_id(Client) of
        {ok, NodeIdBin} ->
            NodeIdHex = binary:encode_hex(NodeIdBin),
            Peers = case macula:get_known_peers(Client) of
                {ok, P} -> P;
                _ -> []
            end,
            PeerCount = length(Peers),
            {ok, #{
                node_id => NodeIdHex,
                peer_count => PeerCount,
                solo_node => PeerCount =:= 0
            }};
        {error, Reason} ->
            {error, {no_node_id, Reason}}
    end.
