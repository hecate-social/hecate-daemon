-module(guide_venture_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% ETS-backed state server (must start first)
        #{
            id => venture_state,
            start => {venture_state, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Fact listeners (one per lifecycle process)
        #{
            id => on_venture_facts_sup,
            start => {on_venture_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_discovery_facts_sup,
            start => {on_discovery_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_design_facts_sup,
            start => {on_design_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_plan_facts_sup,
            start => {on_plan_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_generation_facts_sup,
            start => {on_generation_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_testing_facts_sup,
            start => {on_testing_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_deployment_facts_sup,
            start => {on_deployment_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_monitoring_facts_sup,
            start => {on_monitoring_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => on_rescue_facts_sup,
            start => {on_rescue_facts_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
