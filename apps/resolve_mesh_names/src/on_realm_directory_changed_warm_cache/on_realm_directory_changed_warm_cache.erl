%%% @doc Process Manager: on `realm_directory_changed_v1' (FRTL
%%% rotation, member added/removed, directory version bump),
%%% pre-warm dependent records so the next query hits a warm cache.
%%%
%%% Practical effect: when a realm rotates its root pubkey, this
%%% PM bulk-fetches the new directory + announced realm_stations +
%%% the most recently accessed RMEs, all signature-verified and
%%% installed into L2/L3/L4 before any user query needs them.
%%%
%%% Lives in this slice (target domain: cache_records). Reacts to
%%% events emitted by the underlying mesh substrate (source domain).
%%%
%%% Phase 0: stub.
%%% @end
-module(on_realm_directory_changed_warm_cache).
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
