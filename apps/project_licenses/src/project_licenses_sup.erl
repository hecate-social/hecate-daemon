%%% @doc Top-level supervisor for project_licenses (PRJ).
%%%
%%% Supervises the SQLite store and all projection desk supervisors.
%%% @end
-module(project_licenses_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => project_licenses_store,
            start => {project_licenses_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: license_bought_v1 -> licenses table
        #{
            id => license_bought_v1_to_licenses_sup,
            start => {license_bought_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: license_revoked_v1 -> licenses table
        #{
            id => license_revoked_v1_to_licenses_sup,
            start => {license_revoked_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: license_archived_v1 -> licenses table
        #{
            id => license_archived_v1_to_licenses_sup,
            start => {license_archived_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },

        %% ── Catalog projections (seller-side events) ────────────────────────

        %% Projection: license_initiated_v1 -> catalog table (birth)
        #{
            id => license_initiated_v1_to_catalog_sup,
            start => {license_initiated_v1_to_catalog_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: license_announced_v1 -> catalog table
        #{
            id => license_announced_v1_to_catalog_sup,
            start => {license_announced_v1_to_catalog_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: license_published_v1 -> catalog table
        #{
            id => license_published_v1_to_catalog_sup,
            start => {license_published_v1_to_catalog_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
