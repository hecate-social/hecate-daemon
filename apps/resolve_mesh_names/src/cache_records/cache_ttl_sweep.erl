%%% @doc cache_ttl_sweep: periodic TTL fallback eviction (PLAN PART1
%%% §6.3).
%%%
%%% Push invalidation is the primary mechanism (PMs subscribe to
%%% mesh events and call cache_invalidate on every change). This
%%% sweep is the safety net for entries we missed a push
%%% notification for (network glitch, subscription lapse, etc.).
%%%
%%% Sweep period: 30 s default, configurable via app env
%%% `cache_ttl_sweep_period_ms'.
%%%
%%% Phase 0: scaffold; timer scheduling skeleton + no-op sweep.
%%% Phase 1 wires the real sweep across all 5 cache layers.
%%% @end
-module(cache_ttl_sweep).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(DEFAULT_PERIOD_MS, 30000).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Period = application:get_env(resolve_mesh_names,
                                 cache_ttl_sweep_period_ms,
                                 ?DEFAULT_PERIOD_MS),
    {ok, _Tref} = timer:send_interval(Period, self(), sweep),
    {ok, #{phase => scaffold, period_ms => Period}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.

%% Phase 0: no-op sweep. Phase 1 walks every cache layer and
%% evicts entries past expires_at.
handle_info(sweep, S)       -> {noreply, S};
handle_info(_Info, S)       -> {noreply, S}.

terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
