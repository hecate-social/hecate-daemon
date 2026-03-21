%%% @doc Top-level supervisor for project_realm_memberships (PRJ).
%%%
%%% Starts the ETS store first (creates table), then the merged projection.
%%% @end
-module(project_realm_memberships_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% ETS store (must start first — creates tables)
        #{id => project_realm_memberships_store,
          start => {project_realm_memberships_store, start_link, []},
          restart => permanent, type => worker},
        %% Merged projection: membership lifecycle events -> realm_memberships ETS
        #{id => membership_lifecycle_to_memberships,
          start => {evoq_projection, start_link, [membership_lifecycle_to_memberships, #{}, #{store_id => realm_memberships_store}]},
          restart => permanent, type => worker},
        %% Projection: credentials secured events -> realm_credentials ETS
        #{id => credentials_secured_v1_to_credentials,
          start => {evoq_projection, start_link, [credentials_secured_v1_to_credentials, #{}, #{store_id => realm_memberships_store}]},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
