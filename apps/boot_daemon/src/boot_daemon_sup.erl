%%% @doc Supervisor for boot_daemon.
%%%
%%% Children:
%%%   * boot_tracker — spawns stores, polls readiness, sequences
%%%     post-boot (subscriptions → routes → projection wait → peer
%%%     connect).
%%%
%%% Domain-specific pg relay listeners live in their owning domain
%%% app (e.g. listen_for_inherited_realm_memberships in
%%% guide_realm_memberships). boot_daemon only exposes the seam —
%%% pg group + broadcast helper via the boot_daemon facade.
%%% @end
-module(boot_daemon_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 60
    },
    Children = [
        #{id    => boot_tracker,
          start => {boot_tracker, start_link, []},
          type  => worker}
    ],
    {ok, {SupFlags, Children}}.
