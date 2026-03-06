%%% @doc Top-level supervisor for query_launcher (QRY).
%%%
%%% No children needed - this app only provides API handlers.
%%% @end
-module(query_launcher_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, []}}.
