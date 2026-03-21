%%% @doc Supervisor for query_site.
%%%
%%% Empty children — queries are stateless cowboy handlers.
-module(query_site_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [],
    {ok, {SupFlags, Children}}.
