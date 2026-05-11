%%% @doc UDP/53 (or 5353) listener — receives RFC 1035 datagrams,
%%% hands them to the resolution pipeline, sends responses back.
%%%
%%% Phase 0: scaffold. The gen_server boots into idle state — no
%%% socket open. Phase 1 will: open a UDP socket on the configured
%%% bind/port (`bind' / `udp_port' app env), set
%%% `{active, once}' read loop, parse incoming queries via
%%% `parse_query:parse/1', dispatch to the resolution pipeline,
%%% serialise responses via `compose_response:compose/1', send
%%% back to the source endpoint.
%%%
%%% EDNS0 OPT pseudo-RR is honoured for buffer-size negotiation +
%%% extended-DNS-error code carry. Above 512 bytes (or the
%%% client-advertised UDP payload size) the response sets TC=1 to
%%% force TCP retry.
%%% @end
-module(listen_udp).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Phase 1: open the socket here. For now boot idle so the
    %% supervisor tree comes up cleanly.
    {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
