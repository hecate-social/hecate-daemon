%%% @doc Slice-root supervisor for resolve_mesh_names.
%%%
%%% Supervises desk supervisors only — never workers directly. Each
%%% desk owns its own supervisor + worker(s) per the vertical-slicing
%%% rule in the workspace `CLAUDE.md`.
%%%
%%% Boot order (one_for_one): trust anchors and caches first (every
%%% other desk depends on their ETS tables existing); then the
%%% lookup primitive; then the higher-level desks (resolve_mri,
%%% verify_trust_chain, describe_mri, backlinks, watch_mri); then
%%% the PMs (they subscribe to mesh events the moment they boot, so
%%% the cache must already be alive to receive their invalidations).
%%% library_api is not supervised — it's a pure function module.
%%% @end
-module(resolve_mesh_names_sup).
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
        %% Foundation: trust anchors + caches own ETS tables that
        %% every other desk reads from.
        desk_sup(trust_anchors_sup),
        desk_sup(cache_records_sup),

        %% Lookup primitive: wraps macula:find_record + retry + dedup.
        desk_sup(lookup_via_dht_sup),

        %% Trust-chain state machine driver + 5 verifiers.
        desk_sup(verify_trust_chain_sup),

        %% Public-API desks (resolve, describe, backlinks, watch).
        desk_sup(resolve_mri_sup),
        desk_sup(describe_mri_sup),
        desk_sup(backlinks_sup),
        desk_sup(watch_mri_sup),

        %% Process Managers — invalidate / warm caches in response to
        %% record-observed events. Subscribe at boot; cache must be alive.
        desk_sup(on_record_observed_invalidate_cache_sup),
        desk_sup(on_realm_directory_changed_warm_cache_sup)
    ],
    {ok, {SupFlags, Children}}.

desk_sup(SupModule) ->
    #{id      => SupModule,
      start   => {SupModule, start_link, []},
      restart => permanent,
      type    => supervisor,
      modules => [SupModule]}.
