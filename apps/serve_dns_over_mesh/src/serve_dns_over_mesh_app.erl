%%% @doc OTP application module for serve_dns_over_mesh.
%%%
%%% Phase 0 (this commit): scaffold. The app starts the supervisor
%%% tree but every module is a stub that returns
%%% `{error, not_yet_implemented}'. Phase 1 fills in the listeners,
%%% label algebra, trust chain, and caches per
%%% `macula-architecture/plans/PLAN_DNS_OVER_MESH_PART1.md'.
%%% @end
-module(serve_dns_over_mesh_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    serve_dns_over_mesh_sup:start_link().

stop(_State) ->
    ok.
