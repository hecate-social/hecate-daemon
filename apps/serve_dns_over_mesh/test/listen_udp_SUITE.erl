%%% @doc CT suite for the UDP DNS listener. PLAN_DNS_OVER_MESH_PART1
%%% §5, §9.1.
%%%
%%% Exercises the socket plumbing end-to-end: the listener binds an
%%% (ephemeral) UDP port, a client sends a real DNS query, and the
%%% reply comes back over the wire.
%%%
%%% The mesh resolution path needs a connected macula pool (not
%%% available in CT), so these tests cover the no-pool-needed
%%% paths: REFUSED for a non-mesh qname, and no-reply for a garbled
%%% packet. The mesh-resolves path is covered by serve_query_SUITE
%%% with a stubbed find_fn.
%%% @end
-module(listen_udp_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    binds_and_reports_port/1,
    non_mesh_query_gets_refused/1,
    garbled_packet_gets_no_reply/1
]).

-define(REFUSED, 5).

all() ->
    [binds_and_reports_port,
     non_mesh_query_gets_refused,
     garbled_packet_gets_no_reply].

init_per_suite(Config) ->
    application:set_env(serve_dns_over_mesh, mesh_suffix, <<"macula.io.">>),
    Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    cleanup([listen_udp]),
    application:set_env(serve_dns_over_mesh, bind, "127.0.0.1"),
    application:set_env(serve_dns_over_mesh, udp_port, 0),   %% ephemeral
    {ok, _} = listen_udp:start_link(),
    {ok, Port} = listen_udp:port(),
    [{port, Port} | Config].

end_per_testcase(_TC, _Config) ->
    cleanup([listen_udp]),
    application:unset_env(serve_dns_over_mesh, udp_port),
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

%% Send a packet to the listener and return the reply binary, or
%% `timeout' if none arrives.
ask(Port, Packet) ->
    {ok, Client} = gen_udp:open(0, [binary, {active, false}]),
    try
        ok = gen_udp:send(Client, {127,0,0,1}, Port, Packet),
        case gen_udp:recv(Client, 0, 1000) of
            {ok, {_Ip, _Port, Resp}} -> Resp;
            {error, timeout}         -> timeout
        end
    after
        gen_udp:close(Client)
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
    Q = make_query(16#1234, <<"www.example.com.">>, a),
    Resp = ask(Port, Q),
    true = is_binary(Resp),
    ?REFUSED = rcode(Resp),
    %% The id is echoed back.
    <<16#1234:16, _/binary>> = Resp,
    ok.

garbled_packet_gets_no_reply(Config) ->
    Port = ?config(port, Config),
    %% Too short to even have a header → serve_query returns `drop'
    %% → the listener sends nothing → the client times out.
    timeout = ask(Port, <<1, 2, 3>>),
    ok.
