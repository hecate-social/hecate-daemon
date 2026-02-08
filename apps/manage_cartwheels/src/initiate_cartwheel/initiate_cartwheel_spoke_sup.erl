%%% @doc Spoke supervisor for initiate_cartwheel
%%%
%%% Supervises all workers for the initiate_cartwheel spoke:
%%% - subscribe_to_cartwheel_identified: Listens for cartwheel_identified facts
%%%
%%% The policy (on_cartwheel_identified_maybe_initiate_cartwheel) is stateless
%%% and doesn't need supervision.
%%% @end
-module(initiate_cartwheel_spoke_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },

    Children = [
        #{
            id => subscribe_to_cartwheel_identified,
            start => {subscribe_to_cartwheel_identified, start_link, []},
            restart => permanent,
            type => worker
        }
    ],

    {ok, {SupFlags, Children}}.
