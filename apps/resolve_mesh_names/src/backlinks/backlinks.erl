%%% @doc backlinks desk: reverse-direction queries.
%%%
%%% "Who endorsed this name?" "Who delegated to this station?"
%%% Sources (PLAN PART1 §4.2):
%%%   1. realm_directory.trust_delegates listing
%%%   2. RME records signed by realm root or trust delegates whose
%%%      `path' field matches this MRI
%%%
%%% Cached separately from resolve/2 (different invalidation
%%% triggers). Bounded result size; pagination via continuation
%%% tokens for large realms.
%%%
%%% Phase 0: stub.
%%% @end
-module(backlinks).
-behaviour(gen_server).

-export([start_link/0, backlinks/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Reverse query: who points at this MRI.
-spec backlinks(term(), binary()) -> {ok, [map()]} | {error, atom()}.
backlinks(_Pool, _Mri) -> {error, backlinks_not_yet_implemented}.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
