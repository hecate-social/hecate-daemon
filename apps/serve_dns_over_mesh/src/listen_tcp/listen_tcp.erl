%%% @doc TCP DNS listener (RFC 1035 §4.2.2 / RFC 7766). This is
%%% the truncation fallback: when a UDP response exceeds the
%%% client's buffer the bridge sets TC=1, and a conforming client
%%% retries the query here over TCP/53 — where the 2-byte length
%%% prefix means no practical size cap.
%%%
%%% Framing: `{packet, 2}' on the socket — Erlang strips the
%%% 2-byte length prefix on recv and prepends it on send, which
%%% is exactly DNS-over-TCP's wire format.
%%%
%%% Architecture: the gen_server opens the listen socket and
%%% spawn_links a dedicated acceptor process (an `accept → spawn
%%% per-connection handler → accept' loop). If the acceptor dies
%%% the linked gen_server dies and the supervisor restarts the
%%% whole listener (re-opening the socket). Each accepted
%%% connection is handled in its own short-lived process — it can
%%% carry multiple queries (RFC 7766 §6.2.1) and is dropped after
%%% an idle timeout (`tcp_idle_timeout_ms', default 30 s) or peer
%%% close.
%%%
%%% Bind: `bind' + `tcp_port' app env (default "127.0.0.1":5353 —
%%% unprivileged). On bind failure: log a warning, stay alive in
%%% a `no_socket' state (DNS-over-mesh's TCP fallback disabled,
%%% rest of the daemon unaffected). The macula pool is fetched
%%% lazily per query via `hecate_mesh:get_client/0'.
%%% @end
-module(listen_tcp).
-behaviour(gen_server).

-export([start_link/0, port/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(DEFAULT_BIND, "127.0.0.1").
-define(DEFAULT_PORT, 5353).
-define(DEFAULT_IDLE_MS, 30000).
-define(MAX_QUERY_SIZE, 65535).   %% 16-bit length-prefix ceiling

%% @doc The bound TCP port, or `{error, no_socket}'.
-spec port() -> {ok, inet:port_number()} | {error, no_socket}.
port() ->
    gen_server:call(?MODULE, port).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    BindStr = application:get_env(serve_dns_over_mesh, bind, ?DEFAULT_BIND),
    Port    = application:get_env(serve_dns_over_mesh, tcp_port, ?DEFAULT_PORT),
    case open_listen(BindStr, Port) of
        {ok, ListenSock} ->
            {ok, ActualPort} = inet:port(ListenSock),
            Acceptor = spawn_link(fun() -> accept_loop(ListenSock) end),
            logger:info("serve_dns_over_mesh: TCP listener bound on ~s:~p",
                        [BindStr, ActualPort]),
            {ok, #{listen => ListenSock, acceptor => Acceptor,
                   port => ActualPort, bind => BindStr}};
        {error, Reason} ->
            logger:warning("serve_dns_over_mesh: TCP listener could not bind "
                           "~s:~p (~p) — DNS-over-mesh TCP fallback disabled "
                           "until the port is free and the slice restarts",
                           [BindStr, Port, Reason]),
            {ok, #{listen => undefined, acceptor => undefined,
                   port => undefined, bind => BindStr}}
    end.

open_listen(BindStr, Port) ->
    case inet:parse_address(BindStr) of
        {ok, BindIp} ->
            gen_tcp:listen(Port, [binary, {packet, 2}, {active, false},
                                  {reuseaddr, true}, {ip, BindIp},
                                  {backlog, 64}]);
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
handle_info(_Info, S) -> {noreply, S}.

terminate(_Reason, #{listen := ListenSock}) when is_port(ListenSock) ->
    catch gen_tcp:close(ListenSock),
    ok;
terminate(_Reason, _S) ->
    ok.

code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Acceptor + per-connection handler
%%====================================================================

accept_loop(ListenSock) ->
    case gen_tcp:accept(ListenSock) of
        {ok, Sock} ->
            Handler = spawn(fun() -> connection_loop(Sock) end),
            ok = gen_tcp:controlling_process(Sock, Handler),
            Handler ! go,
            accept_loop(ListenSock);
        {error, closed} ->
            ok;                       %% listen socket closed — listener shutting down
        {error, Reason} ->
            exit({accept_failed, Reason})
    end.

connection_loop(Sock) ->
    %% Wait for the acceptor to transfer ownership.
    receive go -> ok after 1000 -> ok end,
    Idle = application:get_env(serve_dns_over_mesh, tcp_idle_timeout_ms,
                               ?DEFAULT_IDLE_MS),
    serve_connection(Sock, Idle).

serve_connection(Sock, Idle) ->
    case gen_tcp:recv(Sock, 0, Idle) of
        {ok, Query} when byte_size(Query) =< ?MAX_QUERY_SIZE ->
            Pool = mesh_pool(),
            case serve_query:handle(Pool, Query, #{}) of
                {ok, Resp} ->
                    case gen_tcp:send(Sock, Resp) of
                        ok         -> serve_connection(Sock, Idle);
                        {error, _} -> close(Sock)
                    end;
                drop ->
                    %% Malformed query with no answerable header —
                    %% RFC 7766 §8: just close the connection.
                    close(Sock)
            end;
        {ok, _TooBig} ->
            close(Sock);
        {error, closed}  -> ok;
        {error, timeout} -> close(Sock);
        {error, _}       -> close(Sock)
    end.

close(Sock) ->
    catch gen_tcp:close(Sock),
    ok.

mesh_pool() ->
    case catch hecate_mesh:get_client() of
        {ok, Pool} when is_pid(Pool) -> Pool;
        _                            -> undefined
    end.
