%%% @doc Top-level supervisor for project_payments (PRJ).
%%%
%%% Starts the ETS store first (creates tables), then the merged projection.
%%% @end
-module(project_payments_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Projections = [
        payment_lifecycle_to_payments
    ],
    Children = [
        #{
            id => project_payments_store,
            start => {project_payments_store, start_link, []},
            restart => permanent,
            type => worker
        }
        | [#{
            id => Mod,
            start => {evoq_projection, start_link, [Mod, #{}, #{store_id => payments_store}]},
            restart => permanent,
            type => worker
        } || Mod <- Projections]
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
