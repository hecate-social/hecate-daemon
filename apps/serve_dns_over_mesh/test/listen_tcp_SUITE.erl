%%% @doc CT suite for the TCP DNS listener. PLAN_DNS_OVER_MESH_PART1
%%% §5, §9.1.
%%%
%%% Exercises the socket plumbing: the listener binds an ephemeral
%%% TCP port with {packet,2} framing, a client connects and sends
%%% real DNS-over-TCP queries, the replies come back length-prefixed.
%%% Covers the no-pool-needed paths (REFUSED for non-mesh), the
%%% multi-query-per-connection contract (RFC 7766 §6.2.1), and the
%%% idle-timeout close.
%%% @end
-module(listen_tcp_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    binds_and_reports_port/1,
    non_mesh_query_gets_refused/1,
    two_queries_on_one_connection/1,
    idle_connection_is_closed/1,
    garbled_query_closes_connection/1
]).

-define(REFUSED, 5).

all() ->
    [binds_and_reports_port,
     non_mesh_query_gets_refused,
     two_queries_on_one_connection,
     idle_connection_is_closed,
     garbled_query_closes_connection].

init_per_suite(Config) ->
    application:set_env(serve_dns_over_mesh, mesh_suffix, <<"macula.io.">>),
    Config.
end_per_suite(_Config) -> ok.

init_per_testcase(TC, Config) ->
    cleanup([listen_tcp]),
    application:set_env(serve_dns_over_mesh, bind, "127.0.0.1"),
    application:set_env(serve_dns_over_mesh, tcp_port, 0),   %% ephemeral
    %% A short idle timeout for the idle-close test; generous for others.
    IdleMs = case TC of idle_connection_is_closed -> 200; _ -> 5000 end,
    application:set_env(serve_dns_over_mesh, tcp_idle_timeout_ms, IdleMs),
    {ok, _} = listen_tcp:start_link(),
    {ok, Port} = listen_tcp:port(),
    [{port, Port} | Config].

end_per_testcase(_TC, _Config) ->
    cleanup([listen_tcp]),
    application:unset_env(serve_dns_over_mesh, tcp_port),
    application:unset_env(serve_dns_over_mesh, tcp_idle_timeout_ms),
    application:unset_env(serve_dns_over_mesh, bind),
    ok.

cleanup(Names) ->
    [case whereis(N) of
         undefined -> ok;
         Pid       -> catch gen_server:stop(Pid, normal, 1000)
     end || N <- Names],
    ok.

%%====================================================================
%% Helpers
%%====================================================================

make_query(Id, QNameFqdn, QTypeAtom) ->
    Flags  = 1 bsl 8,
    Header = <<Id:16, Flags:16, 1:16, 0:16, 0:16, 0:16>>,
    QName  = compose_response:encode_name(QNameFqdn),
    QType  = parse_query:qtype_value(QTypeAtom),
    <<Header/binary, QName/binary, QType:16, 1:16>>.

connect(Port) ->
    {ok, S} = gen_tcp:connect({127,0,0,1}, Port,
                              [binary, {packet, 2}, {active, false}]),
    S.

ask(Sock, Packet) ->
    ok = gen_tcp:send(Sock, Packet),
    case gen_tcp:recv(Sock, 0, 2000) of
        {ok, Resp}       -> Resp;
        {error, closed}  -> closed;
        {error, timeout} -> timeout
    end.

rcode(<<_Id:16, Flags:16, _/binary>>) -> Flags band 16#0F.

%%====================================================================
%% Tests
%%====================================================================

binds_and_reports_port(Config) ->
    Port = ?config(port, Config),
    true = is_integer(Port) andalso Port > 0,
    ok.

non_mesh_query_gets_refused(Config) ->
    Port = ?config(port, Config),
    S = connect(Port),
    Resp = ask(S, make_query(16#1234, <<"www.example.com.">>, a)),
    true = is_binary(Resp),
    ?REFUSED = rcode(Resp),
    <<16#1234:16, _/binary>> = Resp,
    gen_tcp:close(S),
    ok.

two_queries_on_one_connection(Config) ->
    %% RFC 7766: a TCP connection can carry multiple queries.
    Port = ?config(port, Config),
    S = connect(Port),
    R1 = ask(S, make_query(16#0001, <<"a.example.com.">>, a)),
    R2 = ask(S, make_query(16#0002, <<"b.example.com.">>, aaaa)),
    ?REFUSED = rcode(R1),
    ?REFUSED = rcode(R2),
    <<16#0001:16, _/binary>> = R1,
    <<16#0002:16, _/binary>> = R2,
    gen_tcp:close(S),
    ok.

idle_connection_is_closed(Config) ->
    %% Connect, send nothing — the server closes after the (short,
    %% test-configured) idle timeout.
    Port = ?config(port, Config),
    S = connect(Port),
    %% recv with a timeout longer than the server's idle timeout —
    %% the server closing the socket surfaces as {error, closed}.
    {error, closed} = gen_tcp:recv(S, 0, 1000),
    gen_tcp:close(S),
    ok.

garbled_query_closes_connection(Config) ->
    %% A query too short to have a header → serve_query returns
    %% `drop' → the connection handler closes the socket (RFC 7766 §8).
    Port = ?config(port, Config),
    S = connect(Port),
    ok = gen_tcp:send(S, <<1, 2, 3>>),
    {error, closed} = gen_tcp:recv(S, 0, 1000),
    gen_tcp:close(S),
    ok.
