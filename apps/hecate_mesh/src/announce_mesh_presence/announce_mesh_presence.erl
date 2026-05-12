%%% @doc Mesh presence announcer.
%%%
%%% Publishes a presence fact on the app-tier topic built via
%%% `hecate_topics`: `{realm}/beam-campus/hecate/presence/announced_v1`.
%%% Called once after probes complete (initial announcement) and every
%%% 60s by the coordinator heartbeat timer.
%%% @end
-module(announce_mesh_presence).

-export([announce/2]).

-spec announce(macula:pool(), map()) -> ok | {error, term()}.
announce(Pool, ProbeResults) ->
    Identity = hecate_identity:agent_id(),
    RealmId = macula_realm:id(application:get_env(hecate, realm, <<"io.macula">>)),
    Topic = hecate_topics:app_fact(<<"presence">>, <<"announced">>, 1),
    Version = app_version(),
    Capabilities = derive_capabilities(ProbeResults),

    Fact = #{
        identity => Identity,
        version => Version,
        capabilities => Capabilities,
        timestamp => erlang:system_time(millisecond)
    },

    case macula:publish(Pool, RealmId, Topic, Fact) of
        ok ->
            PeerCount = case macula:status(Pool) of
                {ok, #{healthy_links := N}} -> N;
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
