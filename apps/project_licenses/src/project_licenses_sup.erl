%%% @doc Top-level supervisor for project_licenses (PRJ).
%%%
%%% Starts the ETS store first (creates table), then merged projection.
%%% @end
-module(project_licenses_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => project_licenses_store,
            start => {project_licenses_store, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => license_lifecycle_to_licenses,
            start => {evoq_projection, start_link, [license_lifecycle_to_licenses, #{}, #{store_id => licenses_store}]},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
