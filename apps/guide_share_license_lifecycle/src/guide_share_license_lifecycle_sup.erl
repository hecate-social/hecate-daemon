%%% @doc Top-level supervisor for Phase D share-license domain.
%%%
%%% Hosts the pg-emitters (internal event relay), the batched mesh
%%% emitter (issued-batch), and the mesh listeners that dispatch
%%% accept_license / end_license on inbound traffic.
%%% @end
-module(guide_share_license_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% Internal pg emitters (evoq handler → pg broadcast)
        emitter(license_issued_v1_to_pg),
        emitter(license_accepted_v1_to_pg),
        emitter(license_ended_v1_to_pg),

        %% Single-event mesh emitter: issuer-side revoke → mesh FACT.
        emitter(share_license_revoked_v1_to_mesh),

        %% Batched mesh emitter: gen_server owns the buffer + flush
        %% timer; evoq handler `license_issued_v1_to_batch` forwards
        %% incoming events to it via cast.
        #{id => licenses_issued_batch_emitter,
          start => {licenses_issued_batch_emitter, start_link, []},
          restart => permanent, shutdown => 5000, type => worker,
          modules => [licenses_issued_batch_emitter]},

        emitter(license_issued_v1_to_batch),

        %% Mesh listeners (gen_servers that subscribe once mesh is up)
        #{id => listen_for_license_batch,
          start => {listen_for_license_batch, start_link, []},
          restart => permanent, shutdown => 5000, type => worker,
          modules => [listen_for_license_batch]},

        #{id => listen_for_license_revoked,
          start => {listen_for_license_revoked, start_link, []},
          restart => permanent, shutdown => 5000, type => worker,
          modules => [listen_for_license_revoked]},

        %% Reconnect-catch-up worker — polls realm server's replay RPC
        %% and reissues accept/end dispatches for events missed offline.
        #{id => catch_up_realm_licenses,
          start => {catch_up_realm_licenses, start_link, []},
          restart => permanent, shutdown => 5000, type => worker,
          modules => [catch_up_realm_licenses]}
    ],
    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id => Mod,
      start => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent, shutdown => 5000, type => worker,
      modules => [Mod]}.
