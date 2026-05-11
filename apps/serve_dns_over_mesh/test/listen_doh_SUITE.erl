%%% @doc CT suite for the DoH endpoint (RFC 8484). PLAN_DNS_OVER_MESH_PART1
%%% §5, §9.1.
%%%
%%% Spins up a minimal Cowboy listener carrying just the
%%% `listen_doh:routes/0' route, then exercises it with httpc:
%%%   - POST application/dns-message → DNS response, decode the rcode
%%%   - GET ?dns=<base64url(query)> → same
%%%   - GET without a `dns' param → 400
%%%   - method other than GET/POST → 405
%%%   - response Content-Type is application/dns-message
%%%
%%% The DNS resolution path has no mesh pool in CT, so the queries
%%% used are non-mesh names (→ REFUSED) — that still exercises the
%%% full DoH ↔ serve_query ↔ wire-codec round-trip.
%%% @end
-module(listen_doh_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    post_dns_message/1,
    get_dns_param/1,
    get_without_dns_param_is_400/1,
    put_is_405/1,
    response_content_type/1
]).

-define(REFUSED, 5).
-define(CT_DNS, "application/dns-message").

all() ->
    [post_dns_message,
     get_dns_param,
     get_without_dns_param_is_400,
     put_is_405,
     response_content_type].

init_per_suite(Config) ->
    application:set_env(serve_dns_over_mesh, mesh_suffix, <<"macula.io.">>),
    application:set_env(serve_dns_over_mesh, doh_path, "/dns-query"),
    {ok, _} = application:ensure_all_started(cowboy),
    {ok, _} = application:ensure_all_started(inets),
    Config.

end_per_suite(_Config) ->
    application:unset_env(serve_dns_over_mesh, doh_path),
    ok.

init_per_testcase(_TC, Config) ->
    Dispatch = cowboy_router:compile([{'_', listen_doh:routes()}]),
    {ok, _} = cowboy:start_clear(doh_test_listener,
                                 [{ip, {127,0,0,1}}, {port, 0}],
                                 #{env => #{dispatch => Dispatch}}),
    Port = ranch:get_port(doh_test_listener),
    [{port, Port} | Config].

end_per_testcase(_TC, _Config) ->
    catch cowboy:stop_listener(doh_test_listener),
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

url(Port, Path) ->
    "http://127.0.0.1:" ++ integer_to_list(Port) ++ Path.

http_post(Port, Path, ContentType, Body) ->
    Req = {url(Port, Path), [], ContentType, Body},
    httpc:request(post, Req, [{timeout, 2000}], [{body_format, binary}]).

http_get(Port, Path) ->
    httpc:request(get, {url(Port, Path), []}, [{timeout, 2000}],
                  [{body_format, binary}]).

http_put(Port, Path) ->
    httpc:request(put, {url(Port, Path), [], "text/plain", <<>>},
                  [{timeout, 2000}], [{body_format, binary}]).

base64url(Bin) ->
    %% base64url, strip padding.
    B = base64:encode(Bin, #{mode => urlsafe}),
    binary:replace(B, <<"=">>, <<>>, [global]).

status({ok, {{_Http, Status, _Reason}, _Headers, _Body}}) -> Status.
body({ok, {_StatusLine, _Headers, Body}}) -> Body.
header(Name, {ok, {_StatusLine, Headers, _Body}}) ->
    proplists:get_value(string:lowercase(Name), Headers).

rcode(<<_Id:16, Flags:16, _/binary>>) -> Flags band 16#0F.

%%====================================================================
%% Tests
%%====================================================================

post_dns_message(Config) ->
    Port = ?config(port, Config),
    Q = make_query(16#0011, <<"www.example.com.">>, a),
    Resp = http_post(Port, "/dns-query", ?CT_DNS, Q),
    200 = status(Resp),
    DnsResp = body(Resp),
    ?REFUSED = rcode(DnsResp),
    <<16#0011:16, _/binary>> = DnsResp,
    ok.

get_dns_param(Config) ->
    Port = ?config(port, Config),
    Q = make_query(16#0012, <<"foo.example.com.">>, aaaa),
    Path = "/dns-query?dns=" ++ binary_to_list(base64url(Q)),
    Resp = http_get(Port, Path),
    200 = status(Resp),
    ?REFUSED = rcode(body(Resp)),
    <<16#0012:16, _/binary>> = body(Resp),
    ok.

get_without_dns_param_is_400(Config) ->
    Port = ?config(port, Config),
    400 = status(http_get(Port, "/dns-query")),
    400 = status(http_get(Port, "/dns-query?dns=")),
    ok.

put_is_405(Config) ->
    Port = ?config(port, Config),
    405 = status(http_put(Port, "/dns-query")),
    ok.

response_content_type(Config) ->
    Port = ?config(port, Config),
    Q = make_query(16#0013, <<"x.example.com.">>, a),
    Resp = http_post(Port, "/dns-query", ?CT_DNS, Q),
    CT = header("content-type", Resp),
    %% application/dns-message (possibly with parameters appended).
    {0, _} = binary:match(list_to_binary(CT), <<"application/dns-message">>),
    ok.
