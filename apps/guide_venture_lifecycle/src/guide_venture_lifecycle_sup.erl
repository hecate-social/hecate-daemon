%%% @doc guide_venture_lifecycle top-level supervisor
%%%
%%% Supervises emitters for venture lifecycle events:
%%% - venture_initiated_v1_to_mesh: mesh emitter
%%% - venture_initiated_v1_to_tui: TUI SSE broadcaster
%%% - discovery_started_v1_to_mesh: mesh emitter
%%% - discovery_started_v1_to_tui: TUI SSE broadcaster
%%% - division_identified_v1_to_mesh: mesh emitter
%%% @end
-module(guide_venture_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        #{
            id => venture_initiated_v1_to_mesh,
            start => {venture_initiated_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => venture_initiated_v1_to_tui,
            start => {venture_initiated_v1_to_tui, start_link, []},
            restart => permanent,
            type => worker
        },
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
            id => division_identified_v1_to_mesh,
            start => {division_identified_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        }
    ],

    {ok, {SupFlags, Children}}.
