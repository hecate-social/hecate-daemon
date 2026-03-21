%%% @doc Supervisor for the mesh proof coordinator.
%%% @end
-module(mesh_proof_coordinator_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 3,
        period => 30
    },
    Children = [
        #{
            id => mesh_proof_coordinator,
            start => {mesh_proof_coordinator, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [mesh_proof_coordinator]
        }
    ],
    {ok, {SupFlags, Children}}.
