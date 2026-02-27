%%%-------------------------------------------------------------------
%%% @doc Hecate top-level supervisor.
%%%
%%% Supervision tree:
%%% ```
%%% hecate_sup (one_for_one)
%%% ├── hecate_store         - SQLite persistence
%%% ├── hecate_identity      - MRI + keypair
%%% ├── hecate_realm_session - Realm join flow
%%% └── hecate_ucan          - UCAN wallet
%%% '''
%%%
%%% Note: hecate_mesh and hecate_api are now umbrella apps started
%%% separately via the release configuration.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).

%%--------------------------------------------------------------------
%% @doc Start the supervisor.
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid} | {error, Reason} when
    Pid :: pid(),
    Reason :: term().
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%--------------------------------------------------------------------
%% @doc Initialize supervisor with child specs.
%% @end
%%--------------------------------------------------------------------
-spec init(Args) -> {ok, {SupFlags, ChildSpecs}} when
    Args :: term(),
    SupFlags :: supervisor:sup_flags(),
    ChildSpecs :: [supervisor:child_spec()].
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 60
    },
    
    ChildSpecs = [
        %% SQLite store - must start first
        #{
            id => hecate_store,
            start => {hecate_store, start_link, []},
            restart => permanent,
            type => worker
        },
        
        %% Identity management
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

        %% UCAN wallet
        #{
            id => hecate_ucan,
            start => {hecate_ucan, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    
    {ok, {SupFlags, ChildSpecs}}.
