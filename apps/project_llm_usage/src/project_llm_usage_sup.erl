%%% @doc Top-level supervisor for project_llm_usage (PRJ).
%%%
%%% Starts the ETS store first (creates table), then the projection.
%%% @end
-module(project_llm_usage_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => project_llm_usage_store,
          start => {project_llm_usage_store, start_link, []},
          restart => permanent, type => worker},
        #{id => llm_call_tracked_v1_to_llm_calls,
          start => {evoq_projection, start_link, [llm_call_tracked_v1_to_llm_calls, #{}, #{store_id => llm_store}]},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
