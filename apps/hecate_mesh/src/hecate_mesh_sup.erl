-module(hecate_mesh_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% Mesh client connection manager
        #{
            id => hecate_mesh_client,
            start => {hecate_mesh_client, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hecate_mesh_client]
        },
        %% Mesh proof coordinator — orchestrates proof-of-participation ceremony
        #{
            id => mesh_proof_coordinator_sup,
            start => {mesh_proof_coordinator_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [mesh_proof_coordinator_sup]
        }
        %% NOTE: Emitters are supervised by their respective domain supervisors
        %% (vertical slicing), not here (that would be horizontal).

        %% Process manager: realm membership confirmed -> activate mesh
        ,#{
            id => on_realm_membership_confirmed_activate_mesh,
            start => {evoq_event_handler, start_link, [
                on_realm_membership_confirmed_activate_mesh, #{},
                #{store_id => realm_memberships_store}
            ]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [on_realm_membership_confirmed_activate_mesh]
        }
    ],

    {ok, {SupFlags, Children}}.
