%%% @doc Supervisor for project_realm_memberships.
%%%
%%% Starts SQLite store first, then projection workers.
-module(project_realm_memberships_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% SQLite store (must start first)
        #{id => project_realm_memberships_store,
          start => {project_realm_memberships_store, start_link, []},
          restart => permanent, type => worker},

        %% Projections
        #{id => realm_membership_initiated_v1_to_memberships,
          start => {realm_membership_initiated_v1_to_memberships, start_link, []},
          restart => permanent, type => worker},
        #{id => realm_membership_confirmed_v1_to_memberships,
          start => {realm_membership_confirmed_v1_to_memberships, start_link, []},
          restart => permanent, type => worker},
        #{id => realm_membership_revoked_v1_to_memberships,
          start => {realm_membership_revoked_v1_to_memberships, start_link, []},
          restart => permanent, type => worker}
    ],
    {ok, {SupFlags, Children}}.
