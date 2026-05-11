%%% @doc Supervisor for the watch_mri desk.
%%%
%%% Two workers:
%%%   - watch_mri: subscription registry (gen_server)
%%%   - watch_mri_dispatcher: routes incoming push events from
%%%     macula to per-subscription mailboxes
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
          modules => [watch_mri]},
        #{id      => watch_mri_dispatcher,
          start   => {watch_mri_dispatcher, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [watch_mri_dispatcher]}
    ],
    {ok, {SupFlags, Children}}.
