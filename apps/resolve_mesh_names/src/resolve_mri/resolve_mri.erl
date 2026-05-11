%%% @doc resolve_mri desk: single-shot MRI resolution.
%%%
%%% Pipeline (PLAN_RESOLVE_MESH_NAMES_PART1 §7):
%%%   1. classify_mri(Mri) → (Type, Realm, Path)
%%%   2. cache_records:get(L5, Mri) → hit + fresh? return verified
%%%   3. else verify_trust_chain:verify/3 → walks L1..L4 caches first
%%%   4. cache_records:put(L5, Mri, verified)
%%%   5. return verified record(s)
%%%
%%% Phase 0: stub. Phase 1 wires the pipeline through the trust
%%% chain + cache + lookup desks.
%%% @end
-module(resolve_mri).
-behaviour(gen_server).

-export([start_link/0, resolve/2, refresh/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Resolve an MRI to its current verified record(s).
-spec resolve(term(), binary()) -> {ok, [map()]} | {error, atom()}.
resolve(_Pool, _Mri) -> {error, resolve_mri_not_yet_implemented}.

%% @doc Force-refresh: invalidate L5 cache for this MRI and
%% re-resolve. Phase 1 implements via cache_invalidate +
%% subsequent resolve.
-spec refresh(term(), binary()) -> {ok, [map()]} | {error, atom()}.
refresh(_Pool, _Mri) -> {error, refresh_not_yet_implemented}.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
