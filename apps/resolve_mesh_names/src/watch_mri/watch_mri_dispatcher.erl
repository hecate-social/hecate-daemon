%%% @doc watch_mri dispatcher: receives push events from
%%% macula:subscribe_records and routes them to the registered
%%% subscribers for the affected MRI.
%%%
%%% Phase 0: stub gen_server. Phase 1 implements the routing
%%% logic + the message shapes documented in `library_api'.
%%% @end
-module(watch_mri_dispatcher).
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
