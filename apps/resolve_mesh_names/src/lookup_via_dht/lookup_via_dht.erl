%%% @doc lookup_via_dht desk: wraps macula:find_record with retry +
%%% in-flight de-dup.
%%%
%%% Polls with retry (3 attempts, 600 ms each) to compensate for
%%% the documented ~60% per-attempt cross-station flake (see
%%% macula-internal/macula-station/docs/DHT_FIND_FLAKE_ATTEMPT.md).
%%% Two retries bring effective hit rate to ~94%.
%%%
%%% Coordinates with lookup_dedup so concurrent same-key queries
%%% piggyback on one DHT walk (PLAN PART1 §6.4).
%%%
%%% Phase 0: stub.
%%% @end
-module(lookup_via_dht).
-behaviour(gen_server).

-export([start_link/0, find/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Look up a record by storage key in the DHT, with retry.
%% Returns the raw record map (no signature verification — that
%% lives in verify_trust_chain).
-spec find(Pool :: term(), StorageKey :: binary(),
           Opts :: map()) ->
    {ok, map()} | {error, atom()}.
find(_Pool, _StorageKey, _Opts) ->
    {error, lookup_via_dht_not_yet_implemented}.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
