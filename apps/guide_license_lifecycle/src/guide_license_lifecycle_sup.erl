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

        emitter(license_initiated_v1_to_pg),
        emitter(offering_terms_accepted_v1_to_pg),
        emitter(offering_terms_rejected_v1_to_pg),
        emitter(license_bought_v1_to_pg),
        emitter(license_abandoned_v1_to_pg),
        emitter(license_granted_v1_to_pg),
        emitter(license_expired_v1_to_pg),
        emitter(license_renewed_v1_to_pg),
        emitter(license_revoked_v1_to_pg),
        emitter(license_archived_v1_to_pg),

        %% ── Process Managers ─────────────────────────────────────────────────

        %% Free path: accepted terms -> auto-grant
        emitter(on_offering_terms_accepted_grant_license),

        %% Paid path: bought -> auto-grant
        emitter(on_license_bought_grant_license),

        %% Granted -> install plugin (cross-domain)
        emitter(on_license_granted_install_plugin)
    ],

    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id => Mod, start => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent, type => worker}.
