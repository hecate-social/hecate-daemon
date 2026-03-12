%%% @doc Top-level supervisor for project_license_offerings (PRJ).
%%%
%%% Starts the ETS store first (creates tables), then the merged projection.
%%% @end
-module(project_license_offerings_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => project_license_offerings_store,
            start => {project_license_offerings_store, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => offering_lifecycle_to_offerings,
            start => {evoq_projection, start_link, [offering_lifecycle_to_offerings, #{}, #{store_id => license_offerings_store}]},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
