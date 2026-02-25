%%% @doc query_llm_mentorships top-level supervisor
%%% No children — queries are stateless cowboy handlers.
-module(query_llm_mentorships_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {{one_for_one, 10, 10}, []}}.
