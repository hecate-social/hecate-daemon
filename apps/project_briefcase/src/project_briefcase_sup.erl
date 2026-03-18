-module(project_briefcase_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    StoreOpts = #{store_id => briefcase_store},
    Children = [
        #{id => project_briefcase_store,
          start => {project_briefcase_store, start_link, []},
          restart => permanent, type => worker},
        #{id => briefcase_item_lifecycle_to_items,
          start => {evoq_projection, start_link, [briefcase_item_lifecycle_to_items, #{}, StoreOpts]},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
