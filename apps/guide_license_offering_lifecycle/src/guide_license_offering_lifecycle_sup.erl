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

        #{id => offering_initiated_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_initiated_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => offering_announced_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_announced_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => offering_published_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_published_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => offering_retracted_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_retracted_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => offering_amended_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_amended_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => offering_archived_v1_to_pg,
          start => {evoq_event_handler, start_link, [offering_archived_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- Mesh emitters (external, subscribe via evoq -> publish to mesh) --

        #{id => offering_published_v1_to_mesh,
          start => {evoq_event_handler, start_link, [offering_published_v1_to_mesh, #{}]},
          restart => permanent, type => worker},

        %% -- Version refresh (polls GitHub Releases API) --

        #{id => refresh_offering_versions,
          start => {refresh_offering_versions, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
