%%% @doc Top-level supervisor for query_procurements.
%%%
%%% Query handlers are stateless Cowboy handlers, not supervised processes.
%%% The ETS store and projections live in project_procurements.
%%% @end
-module(query_procurements_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, []}}.
