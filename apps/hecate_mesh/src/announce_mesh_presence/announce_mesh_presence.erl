%%% @doc Mesh presence announcer.
%%%
%%% Publishes a presence fact to the {realm}.hecate.presence topic.
%%% Called once after probes complete (initial announcement)
%%% and every 60s by the coordinator heartbeat timer.
%%% @end
-module(announce_mesh_presence).

-export([announce/2]).

-spec announce(pid(), map()) -> ok | {error, term()}.
announce(Client, ProbeResults) ->
    Identity = application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>),
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Topic = <<Realm/binary, ".hecate.presence">>,
    Version = app_version(),
    Capabilities = derive_capabilities(ProbeResults),
    NodeIdHex = case macula:get_node_id(Client) of
        {ok, Bin} -> binary:encode_hex(Bin);
        _ -> <<"unknown">>
    end,

    Fact = #{
        identity => Identity,
        node_id => NodeIdHex,
        version => Version,
        capabilities => Capabilities,
        timestamp => erlang:system_time(millisecond)
    },

    case macula:publish(Client, Topic, Fact) of
        ok ->
            PeerCount = case macula:get_known_peers(Client) of
                {ok, Peers} -> length(Peers);
                _ -> 0
            end,
            broadcast_pg(mesh_presence_announced, #{
                identity => Identity,
                peer_count => PeerCount
            }),
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

%% -- Internal -------------------------------------------------------

derive_capabilities(Probes) ->
    [Name || {Name, #{status := passed}} <- maps:to_list(Probes)].

app_version() ->
    case application:get_key(hecate, vsn) of
        {ok, Vsn} -> list_to_binary(Vsn);
        undefined -> <<"unknown">>
    end.

broadcast_pg(EventType, Data) ->
    Members = try pg:get_members(pg, macula_mesh_lifecycle) catch _:_ -> [] end,
    Msg = {macula_mesh_event, EventType, Data},
    [Pid ! Msg || Pid <- Members],
    ok.
