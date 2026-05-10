%%% @doc TCP/53 (or 5353) listener — accepts framed DNS-over-TCP
%%% connections (2-byte length prefix + RFC 1035 message).
%%%
%%% Phase 0: scaffold. Boots idle. Phase 1 will open a TCP listen
%%% socket, accept loop, per-connection process for the framed
%%% read/write cycle, AXFR/IXFR refusal (RFC 5936/1995 -> REFUSED
%%% with EDE("zone_transfer_disabled")), idle-timeout drop.
%%% @end
-module(listen_tcp_53).
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
