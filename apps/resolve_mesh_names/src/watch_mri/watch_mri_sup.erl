%%% @doc Supervisor for the watch_mri desk.
%%%
%%% One worker: watch_mri — the subscription registry + change-
%%% driven delivery engine. (The earlier scaffold had a separate
%%% watch_mri_dispatcher; folded into watch_mri since the change
%%% stream comes from the invalidation PMs, not a second macula
%%% subscription.)
-module(watch_mri_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => watch_mri,
          start   => {watch_mri, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [watch_mri]}
    ],
    {ok, {SupFlags, Children}}.
