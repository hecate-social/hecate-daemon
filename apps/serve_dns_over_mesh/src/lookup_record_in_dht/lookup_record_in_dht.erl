%%% @doc DHT lookup wrapper — wraps `macula:find_record/2' with the
%%% in-flight de-dup discipline (`lookup_record_dedup'), so that
%%% concurrent same-key queries piggyback on one DHT walk instead of
%%% N parallel ones.
%%%
%%% Phase 0: scaffold. Boots idle. Phase 1 will:
%%%   - take a `Pool', a `StorageKey', and a `Timeout'
%%%   - check the dedup table for an in-flight walk for `StorageKey'
%%%   - if hit: register caller as a waiter, return on completion
%%%   - if miss: register self as the walker, call
%%%     `macula:find_record(Pool, StorageKey)', notify all waiters
%%%
%%% The Pool is the daemon's existing macula client connection; it
%%% lives in `hecate_mesh' (or equivalent) and is passed in by the
%%% listener layer.
%%% @end
-module(lookup_record_in_dht).
-behaviour(gen_server).

-export([start_link/0, lookup/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Lookup `StorageKey' on `Pool' with `TimeoutMs' deadline.
%% De-dups concurrent same-key callers via `lookup_record_dedup'.
%% Returns `{ok, Record}' or `{error, Reason}'.
-spec lookup(macula:pool(), <<_:256>>, non_neg_integer()) ->
    {ok, map()} | {error, term()}.
lookup(_Pool, _StorageKey, _TimeoutMs) ->
    {error, lookup_record_in_dht_not_yet_implemented}.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
