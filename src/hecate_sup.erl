%%%-------------------------------------------------------------------
%%% @doc Hecate top-level supervisor.
%%%
%%% Supervision tree (tier-1 business workers):
%%% ```
%%% hecate_sup (one_for_one)
%%% ├── hecate_identity      - MRI + keypair (encrypted file)
%%% ├── hecate_realm_session - Realm join flow
%%% ├── hecate_ucan          - UCAN wallet (in-memory)
%%% └── hecate_plugin_loader - In-VM plugin loader
%%% '''
%%%
%%% Boot-infrastructure workers (boot_tracker, store spawning, post-boot
%%% sequencing) live in the tier-0 boot_daemon app.
%%%
%%% Note: hecate_mesh and hecate_api are umbrella apps started separately
%%% via the release configuration.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_sup).
-behaviour(supervisor).

-export([start_link/1]).
-export([init/1]).

-define(SERVER, ?MODULE).

%%--------------------------------------------------------------------
%% @doc Start the supervisor with expected store IDs for boot tracking.
%% @end
%%--------------------------------------------------------------------
-spec start_link([atom()]) -> {ok, Pid} | {error, Reason} when
    Pid :: pid(),
    Reason :: term().
start_link(StoreIds) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, StoreIds).

%%--------------------------------------------------------------------
%% @doc Initialize supervisor with child specs.
%% @end
%%--------------------------------------------------------------------
-spec init(Args) -> {ok, {SupFlags, ChildSpecs}} when
    Args :: [atom()],
    SupFlags :: supervisor:sup_flags(),
    ChildSpecs :: [supervisor:child_spec()].
init(_StoreIds) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 60
    },

    ChildSpecs = [
        %% Identity management (encrypted file, no DB dependency)
        #{
            id => hecate_identity,
            start => {hecate_identity, start_link, []},
            restart => permanent,
            type => worker
        },

        %% Realm join session
        #{
            id => hecate_realm_session,
            start => {hecate_realm_session, start_link, []},
            restart => permanent,
            type => worker
        },

        %% UCAN wallet (in-memory)
        #{
            id => hecate_ucan,
            start => {hecate_ucan, start_link, []},
            restart => permanent,
            type => worker
        },

        %% In-VM plugin loader
        #{
            id => hecate_plugin_loader,
            start => {hecate_plugin_loader, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
