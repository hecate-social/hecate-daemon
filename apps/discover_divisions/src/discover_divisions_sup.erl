%%% @doc Top-level supervisor for discover_divisions.
%%%
%%% Starts the embedded ReckonDB store and emitter workers.
%%% @end
-module(discover_divisions_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    StoreConfig = #store_config{
        store_id = discover_divisions_store,
        data_dir = "data/reckon/discover_divisions"
    },
    Children = [
        %% Embedded ReckonDB store (must start first)
        #{
            id => discover_divisions_store,
            start => {reckon_db_sup, start_store, [StoreConfig]},
            restart => permanent,
            type => supervisor
        },
        %% Emitters
        #{
            id => discovery_started_v1_to_mesh,
            start => {discovery_started_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => discovery_started_v1_to_tui,
            start => {discovery_started_v1_to_tui, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => division_discovered_v1_to_mesh,
            start => {division_discovered_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
