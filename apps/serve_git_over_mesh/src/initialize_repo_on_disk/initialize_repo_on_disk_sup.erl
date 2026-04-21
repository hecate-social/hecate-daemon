%%% @doc Desk supervisor for `initialize_repo_on_disk`.
%%%
%%% Wraps the single `evoq_event_handler` worker that creates bare
%%% repositories on disk when `repo_initiated_v1` events are emitted.
%%% @end
-module(initialize_repo_on_disk_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Worker = #{id      => initialize_repo_on_disk,
               start   => {evoq_event_handler, start_link,
                           [initialize_repo_on_disk, #{}]},
               restart => permanent,
               type    => worker},
    {ok, {SupFlags, [Worker]}}.
