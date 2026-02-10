%%% @doc Top-level supervisor for monitor_division.
%%%
%%% Starts the embedded ReckonDB store and emitter workers.
%%% @end
-module(monitor_division_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    StoreConfig = #store_config{
        store_id = monitor_division_store,
        data_dir = "data/reckon/monitor_division"
    },
    Children = [
        %% Embedded ReckonDB store (must start first)
        #{
            id => monitor_division_store,
            start => {reckon_db_sup, start_store, [StoreConfig]},
            restart => permanent,
            type => supervisor
        },
        %% Mesh emitters
        #{
            id => monitoring_started_v1_to_mesh,
            start => {monitoring_started_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => health_check_registered_v1_to_mesh,
            start => {health_check_registered_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => incident_raised_v1_to_mesh,
            start => {incident_raised_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
