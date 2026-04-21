%%% @doc Desk supervisor for `advertise_repo_procedures`.
%%%
%%% Wraps the single worker that registers (and later retracts)
%%% mesh procedure advertisements for each initiated repo.
%%% @end
-module(advertise_repo_procedures_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Worker = #{id      => advertise_repo_procedures,
               start   => {advertise_repo_procedures, start_link, []},
               restart => permanent,
               type    => worker},
    {ok, {SupFlags, [Worker]}}.
