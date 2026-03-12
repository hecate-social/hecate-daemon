%%% @doc Top-level supervisor for project_sales (PRJ).
%%%
%%% Starts the ETS store first (creates tables), then all projections.
%%% @end
-module(project_sales_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Projections = [
        sale_lifecycle_to_sales
    ],
    Children = [
        #{
            id => project_sales_store,
            start => {project_sales_store, start_link, []},
            restart => permanent,
            type => worker
        }
        | [#{
            id => Mod,
            start => {evoq_projection, start_link, [Mod, #{}, #{store_id => sales_store}]},
            restart => permanent,
            type => worker
        } || Mod <- Projections]
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
