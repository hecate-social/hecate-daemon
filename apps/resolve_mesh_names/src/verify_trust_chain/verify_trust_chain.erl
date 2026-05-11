%%% @doc verify_trust_chain desk: 5-link state machine.
%%%
%%% State sequence (PLAN PART1 §5.2):
%%%   need_anchor → need_frtl → have_frtl → need_dir → have_dir →
%%%   need_endorse → have_endorse → need_leaf → have_leaf →
%%%   need_hd? → verified
%%%
%%% Each transition either reads from cache_records (preferred) or
%%% falls back to lookup_via_dht. Each verifier is a pure-function
%%% module (`verify_frtl', `verify_realm_directory', etc.) called
%%% from this driver.
%%%
%%% Failures map to typed `{error, atom()}' returned to the caller.
%%% Wire bridges translate those to wire-protocol responses.
%%%
%%% Phase 0: stub. Phase 1 implements the state machine.
%%% @end
-module(verify_trust_chain).
-behaviour(gen_server).

-export([start_link/0, verify/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Walk the trust chain for an MRI; return the verified leaf
%% record matching the expected leaf_type.
-spec verify(term(), binary(), atom()) -> {ok, map()} | {error, atom()}.
verify(_Pool, _Mri, _LeafType) ->
    {error, verify_trust_chain_not_yet_implemented}.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
