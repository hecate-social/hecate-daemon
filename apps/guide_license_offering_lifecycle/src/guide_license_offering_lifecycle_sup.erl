%%% @doc guide_license_offering_lifecycle top-level supervisor
%%%
%%% Supervises all emitters for the offering lifecycle:
%%% - PG emitters: subscribe to evoq, broadcast to pg groups (internal)
%%% - Mesh emitters: subscribe to evoq, publish to Macula mesh (external)
%%% @end
-module(guide_license_offering_lifecycle_sup).
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
        %% -- PG emitters (internal, subscribe via evoq -> broadcast to pg) --

        emitter(offering_initiated_v1_to_pg),
        emitter(offering_announced_v1_to_pg),
        emitter(offering_published_v1_to_pg),
        emitter(offering_retracted_v1_to_pg),
        emitter(offering_amended_v1_to_pg),
        emitter(offering_archived_v1_to_pg),

        %% -- Mesh emitters (external, subscribe via evoq -> publish to mesh) --

        emitter(offering_published_v1_to_mesh),

        %% -- Version refresh (polls GitHub Releases API) --

        #{id => refresh_offering_versions,
          start => {refresh_offering_versions, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id => Mod, start => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent, type => worker}.
