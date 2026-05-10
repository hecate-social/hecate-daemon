%%% @doc Slice-root supervisor for serve_dns_over_mesh.
%%%
%%% Supervises desk supervisors only — never workers directly. Each
%%% desk owns its own supervisor + worker(s), per the vertical-slicing
%%% rule in the workspace `CLAUDE.md`.
%%%
%%% Boot order is one_for_one: the desks are independent enough that
%%% a single failure shouldn't take the whole slice down. Caches
%%% start before listeners so that a query arriving instantly after
%%% boot doesn't crash on a missing ETS table.
%%% @end
-module(serve_dns_over_mesh_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 10
    },
    Children = [
        %% Caches first — listeners + PMs depend on them existing.
        desk_sup(cache_positive_sup),
        desk_sup(cache_negative_sup),

        %% In-flight DHT lookup de-dup + the actual lookup worker.
        desk_sup(lookup_record_in_dht_sup),

        %% Refresh-near-expires_at background loop.
        desk_sup(refresh_authority_sup),

        %% Process Managers — invalidate / warm caches in response to
        %% record-observed events from the local DHT.
        desk_sup(on_record_observed_invalidate_cache_sup),
        desk_sup(on_realm_directory_changed_warm_cache_sup),

        %% Listeners last — accept queries only once the slice is
        %% otherwise ready.
        desk_sup(listen_udp_53_sup),
        desk_sup(listen_tcp_53_sup),
        desk_sup(listen_doh_sup)
    ],
    {ok, {SupFlags, Children}}.

desk_sup(SupModule) ->
    #{id      => SupModule,
      start   => {SupModule, start_link, []},
      restart => permanent,
      type    => supervisor,
      modules => [SupModule]}.
