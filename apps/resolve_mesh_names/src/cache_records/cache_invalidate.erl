%%% @doc cache_invalidate: orchestrates cache invalidation,
%%% including the cascade from upstream layers down through L5.
%%%
%%% Triggers (PLAN PART1 §6.2):
%%%   - tombstone observed → invalidate target key everywhere
%%%   - realm_directory updated → invalidate L2 + cascade L3+L4+L5
%%%   - frtl updated → invalidate L1 + cascade entire realm subtree
%%%   - rme updated → invalidate L3 + cascade L4+L5 for that path
%%%   - leaf updated for cached MRI → invalidate L4+L5 for that MRI
%%%
%%% Called by both PMs (push-driven) and cache_ttl_sweep (TTL fallback).
%%%
%%% Phase 0: stub.
%%% @end
-module(cache_invalidate).
-behaviour(gen_server).

-export([start_link/0, by_key/2, by_realm/1, by_member_path/2, all/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Invalidate a single (layer, key) pair plus cascades.
-spec by_key(Layer :: atom(), Key :: term()) -> ok.
by_key(_Layer, _Key) -> ok.

%% @doc Invalidate every entry tied to a given realm.
-spec by_realm(RealmId :: binary()) -> ok.
by_realm(_RealmId) -> ok.

%% @doc Invalidate every entry tied to a given (realm, path)
%% endorsement.
-spec by_member_path(RealmId :: binary(), Path :: [binary()]) -> ok.
by_member_path(_RealmId, _Path) -> ok.

%% @doc Nuke everything (operator command; rare).
-spec all() -> ok.
all() -> ok.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
