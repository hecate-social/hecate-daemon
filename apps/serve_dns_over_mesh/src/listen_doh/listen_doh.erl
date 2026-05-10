%%% @doc DoH listener — RFC 8484 (DNS Queries over HTTPS) mounted on
%%% the daemon's existing HTTP/3 endpoint at the configured `doh_path'
%%% (default `/dns-query').
%%%
%%% Phase 0: scaffold. Boots idle. Phase 1 will register a Cowboy
%%% route on hecate_api's listener for {GET,POST} doh_path that
%%% accepts the wire-format query, dispatches to the same resolution
%%% pipeline as listen_udp_53, and returns the wire-format response
%%% with Content-Type: application/dns-message.
%%% @end
-module(listen_doh).
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
