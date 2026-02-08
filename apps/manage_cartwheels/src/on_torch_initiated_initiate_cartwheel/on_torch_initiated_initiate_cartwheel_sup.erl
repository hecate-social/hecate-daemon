%%% @doc Supervisor for on_torch_initiated_initiate_cartwheel process manager
%%%
%%% This supervisor manages the process manager that reacts to torch_initiated_v1
%%% events and initiates cartwheels in the manage_cartwheels domain.
-module(on_torch_initiated_initiate_cartwheel_sup).
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
        #{
            id => on_torch_initiated_initiate_cartwheel,
            start => {on_torch_initiated_initiate_cartwheel, start_link, []},
            restart => permanent,
            type => worker
        }
    ],

    {ok, {SupFlags, Children}}.
