-module(hecate_mesh_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    BackendMod = backend_module(),

    %% Registered under `hecate_mesh_client` regardless of the
    %% underlying module — keeps call sites + whereis checks
    %% backend-agnostic.
    MeshBackendChild = #{
        id => hecate_mesh_client,
        start => {BackendMod, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [BackendMod]
    },

    Children = [MeshBackendChild]
               ++ proof_children(BackendMod)
               ++ daemon_announcer_children(BackendMod)
               ++ realm_pm_children(),
    {ok, {SupFlags, Children}}.

%% @private Resolve the mesh backend module.
%%
%% `client`  — production (`hecate_mesh_client`, real QUIC to relay
%%             fleet). Default.
%% `inproc`  — `hecate_mesh_inproc`, in-process pub/sub + macula's
%%             local stream fabric. Used by CT suites + fast devtime.
%%
%% Set via application env `{hecate, [{mesh_backend, inproc}]}` in
%% sys.config. The prod-local config pins this to `client` explicitly;
%% dev and CT set it to `inproc`.
backend_module() ->
    case application:get_env(hecate, mesh_backend, client) of
        client -> hecate_mesh_client;
        inproc -> hecate_mesh_inproc;
        Other  ->
            logger:warning(
                "[hecate_mesh_sup] unknown mesh_backend=~p, falling back to client",
                [Other]),
            hecate_mesh_client
    end.

%% Mesh proof coordinator only makes sense with the real backend —
%% inproc has no peers to prove to.
proof_children(hecate_mesh_client) ->
    [#{id => mesh_proof_coordinator_sup,
       start => {mesh_proof_coordinator_sup, start_link, []},
       restart => permanent,
       shutdown => 5000,
       type => supervisor,
       modules => [mesh_proof_coordinator_sup]}];
proof_children(_InprocOrOther) ->
    [].

%% Daemon presence announcer — periodically puts a signed
%% `node_record' (kind=daemon) so realm topology dashboards can
%% render the daemon. Only meaningful with the real backend; inproc
%% has no DHT to publish into.
daemon_announcer_children(hecate_mesh_client) ->
    [#{id => announce_daemon_presence,
       start => {announce_daemon_presence, start_link, []},
       restart => permanent,
       shutdown => 5000,
       type => worker,
       modules => [announce_daemon_presence]}];
daemon_announcer_children(_InprocOrOther) ->
    [].

%% The realm-confirmed → activate PM is relevant to both backends:
%% inproc's activate/0 is a no-op, so the PM firing is harmless, and
%% domain code doesn't need to branch on backend.
realm_pm_children() ->
    [#{id => on_realm_membership_confirmed_activate_mesh,
       start => {evoq_event_handler, start_link,
                 [on_realm_membership_confirmed_activate_mesh, #{},
                  #{store_id => realm_memberships_store}]},
       restart => permanent,
       shutdown => 5000,
       type => worker,
       modules => [on_realm_membership_confirmed_activate_mesh]}].
