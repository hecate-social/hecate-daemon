%%% @doc Supervisor for query_mesh_activity. Stateless cowboy handlers.
-module(query_mesh_activity_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [],
    {ok, {SupFlags, Children}}.
