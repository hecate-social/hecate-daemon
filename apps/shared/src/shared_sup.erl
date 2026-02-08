-module(shared_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% No children - shared is just utility modules
    {ok, {{one_for_one, 0, 1}, []}}.
