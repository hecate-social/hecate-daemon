%%% @doc Top-level supervisor for deploy_division.
%%%
%%% Starts the embedded ReckonDB store and emitter workers.
%%% @end
-module(deploy_division_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    StoreConfig = #store_config{
        store_id = deploy_division_store,
        data_dir = "data/reckon/deploy_division"
    },
    Children = [
        %% Embedded ReckonDB store (must start first)
        #{
            id => deploy_division_store,
            start => {reckon_db_sup, start_store, [StoreConfig]},
            restart => permanent,
            type => supervisor
        },
        %% Emitters
        #{
            id => deployment_started_v1_to_mesh,
            start => {deployment_started_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => release_deployed_v1_to_mesh,
            start => {release_deployed_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => rollout_staged_v1_to_mesh,
            start => {rollout_staged_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
