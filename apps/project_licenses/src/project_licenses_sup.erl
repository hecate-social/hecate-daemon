%%% @doc Top-level supervisor for project_licenses (PRJ).
%%%
%%% Starts the ETS store first (creates tables), then all projections.
%%% @end
-module(project_licenses_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Projections = [
        %% Licenses table projections
        license_bought_v1_to_licenses,
        license_revoked_v1_to_licenses,
        license_archived_v1_to_licenses,
        %% Catalog table projection (merged — ordering matters!)
        license_lifecycle_to_catalog,
        %% Cross-domain: plugin events -> licenses table
        plugin_installed_v1_to_licenses,
        plugin_removed_v1_to_licenses,
        plugin_upgraded_v1_to_licenses
    ],
    Children = [
        #{
            id => project_licenses_store,
            start => {project_licenses_store, start_link, []},
            restart => permanent,
            type => worker
        }
        | [#{
            id => Mod,
            start => {evoq_projection, start_link, [Mod, #{}]},
            restart => permanent,
            type => worker
        } || Mod <- Projections]
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
