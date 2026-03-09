%%% @doc guide_license_lifecycle top-level supervisor
%%%
%%% Supervises all emitters and process managers for consumer license lifecycle:
%%% - PG emitters: subscribe to evoq, broadcast to pg groups (internal)
%%% - Process managers: react to domain events, dispatch cross-aggregate commands
%%% @end
-module(guide_license_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% ── PG emitters (internal, subscribe via evoq -> broadcast to pg) ────

        #{id => license_initiated_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_initiated_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => offering_terms_accepted_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_terms_accepted_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => offering_terms_rejected_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_terms_rejected_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => license_bought_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_bought_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => license_abandoned_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_abandoned_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => license_granted_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_granted_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => license_expired_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_expired_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => license_renewed_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_renewed_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => license_revoked_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_revoked_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => license_archived_v1_to_pg,
          start => {evoq_event_handler, start_link, [license_archived_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% ── Process Managers ─────────────────────────────────────────────────

        %% Free path: accepted terms -> auto-grant
        #{id => on_offering_terms_accepted_grant_license,
          start => {evoq_event_handler, start_link, [on_offering_terms_accepted_grant_license, #{}]},
          restart => permanent, type => worker},

        %% Paid path: bought -> auto-grant
        #{id => on_license_bought_grant_license,
          start => {evoq_event_handler, start_link, [on_license_bought_grant_license, #{}]},
          restart => permanent, type => worker},

        %% Granted -> install plugin (cross-domain)
        #{id => on_license_granted_install_plugin,
          start => {evoq_event_handler, start_link, [on_license_granted_install_plugin, #{}]},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
