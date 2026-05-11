%%% @doc Slice-root supervisor for serve_dns_over_mesh (Tier-2 DNS
%%% wire bridge).
%%%
%%% Supervises desk supervisors only. After the 2026-05-11 split
%%% (PLAN_DNS_OVER_MESH re-rooting), this slice is a thin wire
%%% bridge — naming + trust verification + caching all live in
%%% `resolve_mesh_names'. So the supervised desks are just the
%%% three listeners (UDP, TCP, DoH); the qname↔MRI codec,
%%% RRset synthesis, and response composition are pure-function
%%% modules with no process.
%%%
%%% one_for_one: the listeners are independent enough that one
%%% failing shouldn't take the others down.
%%% @end
-module(serve_dns_over_mesh_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 10
    },
    Children = [
        desk_sup(listen_udp_sup),
        desk_sup(listen_tcp_sup),
        desk_sup(listen_doh_sup)
    ],
    {ok, {SupFlags, Children}}.

desk_sup(SupModule) ->
    #{id      => SupModule,
      start   => {SupModule, start_link, []},
      restart => permanent,
      type    => supervisor,
      modules => [SupModule]}.
