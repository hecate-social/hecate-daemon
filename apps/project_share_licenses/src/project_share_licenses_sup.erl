%%% @doc Top-level supervisor for project_share_licenses.
%%%
%%% Starts the ETS store first (creates `my_issued_realm_scoped_active_licenses`
%%% table), then the merged projection that subscribes to `license_issued_v1`,
%%% `share_license_revoked_v1`, and `license_rewrapped_v1` on the
%%% `share_licenses_store`. This index is consumed by the rewrap
%%% process manager on K_realm rotation to find the set of licenses
%%% that need rewrapping for a given (realm, old-version) pair.
%%% @end
-module(project_share_licenses_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => project_share_licenses_store,
          start => {project_share_licenses_store, start_link, []},
          restart => permanent, type => worker},
        #{id => share_license_lifecycle_to_issued_index,
          start => {evoq_projection, start_link,
                    [share_license_lifecycle_to_issued_index,
                     #{},
                     #{store_id => share_licenses_store}]},
          restart => permanent, type => worker},
        #{id => share_license_lifecycle_to_accepted_index,
          start => {evoq_projection, start_link,
                    [share_license_lifecycle_to_accepted_index,
                     #{},
                     #{store_id => share_licenses_store}]},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
