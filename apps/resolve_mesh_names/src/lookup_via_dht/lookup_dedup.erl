%%% @doc lookup_dedup: in-flight ETS de-dup registry.
%%%
%%% When a query hits a cache miss:
%%%   1. Check the in-flight table.
%%%   2. If an entry exists for our key, register self as a waiter.
%%%   3. If no entry, register self as the in-flight worker and
%%%      start the DHT walk.
%%%   4. On result: ETS-broadcast to all waiters; evict in-flight.
%%%
%%% Owns named ETS table `resolve_mesh_names_lookup_dedup'.
%%%
%%% Phase 0: scaffold; ETS table created but functions stub.
%%% @end
-module(lookup_dedup).
-behaviour(gen_server).

-export([start_link/0, claim_or_wait/2, broadcast_result/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, resolve_mesh_names_lookup_dedup).

%% @doc Either claim ownership of a lookup for `Key' (returns
%% `claimed') or register as a waiter (returns `{wait, Ref}').
-spec claim_or_wait(Key :: binary(), Caller :: pid()) ->
    claimed | {wait, reference()} | {error, atom()}.
claim_or_wait(_Key, _Caller) ->
    {error, lookup_dedup_not_yet_implemented}.

%% @doc Broadcast a lookup result to all waiters and evict the
%% in-flight entry.
-spec broadcast_result(Key :: binary(), Result :: term(),
                       OwnerPid :: pid()) -> ok.
broadcast_result(_Key, _Result, _OwnerPid) -> ok.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    catch ets:delete(?TABLE),
    ?TABLE = ets:new(?TABLE, [named_table, public, set,
                              {read_concurrency, true},
                              {write_concurrency, true}]),
    {ok, #{phase => scaffold, table => ?TABLE}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
