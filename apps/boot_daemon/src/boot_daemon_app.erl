%%% @doc boot_daemon application module.
%%%
%%% Tier-0 bootstrap for the hecate daemon:
%%%   * applies HECATE_ERLANG_COOKIE early so cookie-derived identities
%%%     (site_id, encrypted_credentials) are stable before any store
%%%     boots.
%%%   * starts boot_daemon_sup which owns boot_tracker and the pg relay
%%%     listener.
%%%
%%% The root `hecate` application (tier-1) calls
%%% boot_daemon:register_stores/1 after this app is up, handing over
%%% the full store list. boot_daemon then spawns stores, tracks their
%%% readiness, connects Erlang peers, and — when ready — invokes the
%%% post-boot sequence (subscriptions, routes, projection replay).
%%%
%%% Separating this from hecate_app breaks the previous boot race:
%%% hecate_sup used to contain both boot infrastructure (boot_tracker)
%%% and business workers (realm_session, plugin_loader). Business
%%% workers wanted to read stores that hadn't been spawned yet because
%%% spawning was deferred until after the sup started. The two-tier
%%% structure makes the dependency order explicit: boot_daemon first,
%%% business workers after.
%%% @end
-module(boot_daemon_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    logger:info("[boot_daemon] Starting"),
    apply_cluster_cookie(),
    ensure_pg_scope(),
    connect_cluster_peers(),
    boot_daemon_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.

%% @private Apply HECATE_ERLANG_COOKIE if set. Idempotent — no-op when
%% the env var is absent, so single-node / dev setups behave unchanged.
%%
%% Runs before any store boots because the cookie is a decryption key
%% for realm_credentials_secured_v1 events and the seed for site_id.
apply_cluster_cookie() ->
    case os:getenv("HECATE_ERLANG_COOKIE") of
        false ->
            logger:info("[boot_daemon] No HECATE_ERLANG_COOKIE set — keeping vm.args default");
        Cookie when is_list(Cookie) ->
            erlang:set_cookie(node(), list_to_atom(Cookie)),
            logger:info("[boot_daemon] Cluster cookie applied from HECATE_ERLANG_COOKIE")
    end.

%% @private Start the default pg scope before any listener subscribes.
%% `pg:start_link/0` is idempotent — returns `{error, {already_started, _}}`
%% when the scope is already up. Running it here removes the cold-start
%% race where `guide_realm_memberships` workers `pg:join/2` before the
%% scope exists and retry 2s later.
ensure_pg_scope() ->
    case pg:start_link() of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.

%% @private Connect Erlang peers listed in HECATE_CLUSTER_PEERS so the
%% pg seam reaches them before any store replay or mesh activation.
%%
%% Peer-connect used to live in boot_tracker's post-boot sequence, but
%% post-boot only fires after the poll loop sees every expected store
%% ready. `mesh_proof_coordinator:set_running/0` can change the boot
%% phase out of `booting_stores` before that poll completes — which
%% happens whenever realm credentials are already cached from a prior
%% session and the mesh activates in <1s. Once the phase is no longer
%% `booting_stores`, the poll_stores handler bails, `trigger_post_boot`
%% never runs, and peer-connect is silently dropped.
%%
%% Peer-connect has no dependency on stores, projections, or mesh — it
%% just needs the cookie applied and the pg scope up. Both happen in
%% this function's callers above, so peer-connect is safe here at
%% tier-0 boot time. Store-level Khepri joins (HECATE_AUTOJOIN_STORES)
%% stay in post-boot because they DO need stores running.
%%
%% Fired in a spawned process so an unreachable peer (e.g. the other
%% node hasn't finished its own BEAM startup yet) never blocks this
%% node's boot. One-shot: if we miss a peer, its own boot_daemon will
%% connect back when it starts.
connect_cluster_peers() ->
    case os:getenv("HECATE_CLUSTER_PEERS") of
        false ->
            logger:info("[boot_daemon] No HECATE_CLUSTER_PEERS — staying Erlang-unconnected");
        Peers when is_list(Peers) ->
            PeerNodes = [list_to_atom(string:trim(N)) ||
                         N <- string:split(Peers, ",", all), N =/= ""],
            spawn(fun() ->
                Connected = [P || P <- PeerNodes,
                                  net_kernel:connect_node(P) =:= true],
                logger:info("[boot_daemon] Erlang cluster: ~b/~b peers connected (~p)",
                            [length(Connected), length(PeerNodes), Connected])
            end)
    end.
