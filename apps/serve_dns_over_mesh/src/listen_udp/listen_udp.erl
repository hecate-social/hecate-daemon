%%% @doc UDP DNS listener. Opens a UDP socket on the configured
%%% bind/port, reads incoming RFC 1035 datagrams, hands each to
%%% `serve_query', and sends the reply back to the source endpoint.
%%%
%%% Bind: `bind' app env (default `"127.0.0.1"') + `udp_port'
%%% (default 5353 — unprivileged; binding port 53 needs
%%% CAP_NET_BIND_SERVICE, handled at deploy time, not here).
%%%
%%% If the socket can't be opened (port in use, bad bind IP), the
%%% listener logs a warning and stays alive in a `no_socket' state
%%% rather than crash-looping — DNS-over-mesh is then non-functional
%%% (`port/0' returns `{error, no_socket}'), but the rest of the
%%% daemon is unaffected. The operator sees the warning + can free
%%% the port and restart the slice.
%%%
%%% Concurrency: each datagram is served in a short-lived spawned
%%% process so a slow resolution (the trust-chain walk can take up
%%% to ~1.8 s with DHT retries) doesn't block the listener from
%%% accepting more queries. The listener re-arms `{active, once}'
%%% immediately after spawning the worker.
%%%
%%% The macula client pool is fetched lazily per query via
%%% `hecate_mesh:get_client/0'; when the mesh isn't connected,
%%% `serve_query' answers mesh queries SERVFAIL and non-mesh
%%% queries REFUSED (no pool needed for either of those paths).
%%% @end
-module(listen_udp).
-behaviour(gen_server).

-export([start_link/0, port/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(DEFAULT_BIND, "127.0.0.1").
-define(DEFAULT_PORT, 5353).
%% Max accepted query size — RFC 1035 caps a UDP DNS message at
%% 512 octets without EDNS0; with EDNS0 it can be larger but a
%% query is tiny regardless. Anything bigger is almost certainly
%% junk; we still accept up to 4 KiB defensively.
-define(MAX_QUERY_SIZE, 4096).

%% @doc The UDP port the listener actually bound, or
%% `{error, no_socket}' if it couldn't open one.
-spec port() -> {ok, inet:port_number()} | {error, no_socket}.
port() ->
    gen_server:call(?MODULE, port).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    BindStr = application:get_env(serve_dns_over_mesh, bind, ?DEFAULT_BIND),
    Port    = application:get_env(serve_dns_over_mesh, udp_port, ?DEFAULT_PORT),
    case open_socket(BindStr, Port) of
        {ok, Socket} ->
            {ok, ActualPort} = inet:port(Socket),
            logger:info("serve_dns_over_mesh: UDP listener bound on ~s:~p",
                        [BindStr, ActualPort]),
            {ok, #{socket => Socket, port => ActualPort, bind => BindStr}};
        {error, Reason} ->
            logger:warning("serve_dns_over_mesh: UDP listener could not bind "
                           "~s:~p (~p) — DNS-over-mesh disabled until the "
                           "port is free and the slice restarts",
                           [BindStr, Port, Reason]),
            {ok, #{socket => undefined, port => undefined, bind => BindStr}}
    end.

open_socket(BindStr, Port) ->
    case inet:parse_address(BindStr) of
        {ok, BindIp} ->
            gen_udp:open(Port, [binary, {active, once}, {reuseaddr, true},
                                {ip, BindIp}]);
        {error, _} ->
            {error, {bad_bind_address, BindStr}}
    end.

handle_call(port, _From, #{port := undefined} = S) ->
    {reply, {error, no_socket}, S};
handle_call(port, _From, #{port := P} = S) ->
    {reply, {ok, P}, S};
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast(_Msg, S) -> {noreply, S}.

handle_info({udp, Socket, FromIp, FromPort, Packet},
            #{socket := Socket} = State) when byte_size(Packet) =< ?MAX_QUERY_SIZE ->
    serve_async(Socket, FromIp, FromPort, Packet),
    ok = inet:setopts(Socket, [{active, once}]),
    {noreply, State};
handle_info({udp, Socket, _FromIp, _FromPort, _Packet}, #{socket := Socket} = State) ->
    %% Oversized datagram — drop it, re-arm.
    ok = inet:setopts(Socket, [{active, once}]),
    {noreply, State};
handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, #{socket := Socket}) when is_port(Socket) ->
    catch gen_udp:close(Socket),
    ok;
terminate(_Reason, _S) ->
    ok.

code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Per-query worker
%%====================================================================

serve_async(Socket, FromIp, FromPort, Packet) ->
    spawn(fun() ->
        Pool = mesh_pool(),
        case serve_query:handle(Pool, Packet, #{}) of
            {ok, RespBin} -> gen_udp:send(Socket, FromIp, FromPort, RespBin);
            drop          -> ok
        end
    end),
    ok.

%% Lazily fetch the macula client pool. `hecate_mesh' may not be
%% running (some test setups) — treat any failure as "no pool",
%% which serve_query handles gracefully (mesh queries → SERVFAIL).
mesh_pool() ->
    case catch hecate_mesh:get_client() of
        {ok, Pool} when is_pid(Pool) -> Pool;
        _                            -> undefined
    end.
