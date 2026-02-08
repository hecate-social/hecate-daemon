%%% @doc manage_torches top-level supervisor
%%%
%%% Supervises:
%%% - torch_initiated_v1_to_mesh: Emitter that publishes torch initiation facts
%%% - cartwheel_identified_v1_to_mesh: Emitter that publishes cartwheel identification facts
%%%
%%% @end
-module(manage_torches_sup).
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
            id => torch_initiated_v1_to_mesh,
            start => {torch_initiated_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => cartwheel_identified_v1_to_mesh,
            start => {cartwheel_identified_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        }
    ],

    {ok, {SupFlags, Children}}.
