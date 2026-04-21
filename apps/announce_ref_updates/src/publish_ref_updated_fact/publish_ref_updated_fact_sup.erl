%%% @doc Desk supervisor for `publish_ref_updated_fact`.
-module(publish_ref_updated_fact_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Worker = #{id      => publish_ref_updated_fact,
               start   => {publish_ref_updated_fact, start_link, []},
               restart => permanent,
               type    => worker},
    {ok, {SupFlags, [Worker]}}.
