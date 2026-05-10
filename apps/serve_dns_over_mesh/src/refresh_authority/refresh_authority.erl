%%% @doc Background loop that refreshes cache entries approaching
%%% their `expires_at'. Pre-warms the cache so a query that arrives
%%% just past expiry doesn't pay full DHT-walk latency.
%%%
%%% Phase 0: scaffold. Phase 1 will: periodic timer (e.g. every
%%% 30s) scans `cache_positive' for entries whose remaining TTL is
%%% under a refresh threshold, kicks off a fresh `lookup_record_in_dht'
%%% to repopulate them. Throttled so a flood of near-expiry entries
%%% doesn't saturate the DHT.
%%% @end
-module(refresh_authority).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
