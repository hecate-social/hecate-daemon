%%% @doc guide_license_lifecycle top-level supervisor
%%%
%%% Supervises all emitters and process managers for license lifecycle:
%%% - PG emitters: subscribe to evoq, broadcast to pg groups (internal)
%%% - Mesh emitters: subscribe to evoq, publish to Macula mesh (external)
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

        %% Seller-side emitters
        #{id => license_initiated_v1_to_pg,
          start => {license_initiated_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => license_announced_v1_to_pg,
          start => {license_announced_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => license_published_v1_to_pg,
          start => {license_published_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Buyer-side emitters
        #{id => license_bought_v1_to_pg,
          start => {license_bought_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => license_revoked_v1_to_pg,
          start => {license_revoked_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => license_archived_v1_to_pg,
          start => {license_archived_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% ── Mesh emitters (external, subscribe via evoq -> publish to mesh) ──

        #{id => license_published_v1_to_mesh,
          start => {license_published_v1_to_mesh, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
