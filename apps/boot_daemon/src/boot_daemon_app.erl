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
