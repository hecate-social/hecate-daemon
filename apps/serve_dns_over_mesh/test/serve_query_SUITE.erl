%%% @doc CT suite for serve_query — the DNS-bridge lookup pipeline.
%%% PLAN_DNS_OVER_MESH_PART1 §5, §6, §9.1.
%%%
%%% Coverage:
%%%   - non-mesh qname → REFUSED
%%%   - AXFR / IXFR → REFUSED
%%%   - mesh qname with no mesh pool → SERVFAIL
%%%   - station AAAA query with a seeded station_endpoint → NOERROR
%%%     with an AAAA answer (the dig-works-end-to-end path, with
%%%     the DHT faked via Opts.find_fn)
%%%   - station with only v4 hosts, AAAA query → NOERROR, no answer
%%%     (NODATA — name exists, no record of that type)
%%%   - user-type qname → SERVFAIL (resolve_mesh_names returns
%%%     {not_resolvable_yet, user})
%%%   - garbled packet (too short) → drop (no reply)
%%%   - valid header but zero questions → FORMERR
%%% @end
-module(serve_query_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    non_mesh_is_refused/1,
    axfr_is_refused/1,
    no_pool_mesh_query_is_servfail/1,
    station_aaaa_resolves/1,
    station_v4_only_aaaa_is_nodata/1,
    user_mri_is_servfail/1,
    garbled_packet_is_dropped/1,
    zero_question_is_formerr/1
]).

%% RCODE values
-define(NOERROR,  0).
-define(FORMERR,  1).
-define(SERVFAIL, 2).
-define(NXDOMAIN, 3).
-define(NOTIMP,   4).
-define(REFUSED,  5).

all() ->
    [
        non_mesh_is_refused,
        axfr_is_refused,
        no_pool_mesh_query_is_servfail,
        station_aaaa_resolves,
        station_v4_only_aaaa_is_nodata,
        user_mri_is_servfail,
        garbled_packet_is_dropped,
        zero_question_is_formerr
    ].

init_per_suite(Config) ->
    application:set_env(serve_dns_over_mesh, mesh_suffix, <<"macula.io.">>),
    Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    cleanup([trust_anchors, cache_records, cache_invalidate, cache_ttl_sweep,
             lookup_dedup, lookup_via_dht, verify_trust_chain, resolve_mri]),
    {ok, _} = trust_anchors:start_link(),
    {ok, _} = cache_records:start_link(),
    {ok, _} = cache_invalidate:start_link(),
    application:set_env(resolve_mesh_names, cache_ttl_sweep_period_ms, 60000),
    {ok, _} = cache_ttl_sweep:start_link(),
    {ok, _} = lookup_dedup:start_link(),
    {ok, _} = lookup_via_dht:start_link(),
    {ok, _} = verify_trust_chain:start_link(),
    {ok, _} = resolve_mri:start_link(),
    Config.

end_per_testcase(_TC, _Config) ->
    cleanup([resolve_mri, verify_trust_chain, lookup_via_dht, lookup_dedup,
             cache_ttl_sweep, cache_invalidate, cache_records, trust_anchors]),
    application:unset_env(resolve_mesh_names, cache_ttl_sweep_period_ms),
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
    Flags  = 1 bsl 8,    %% RD=1
    Header = <<Id:16, Flags:16, 1:16, 0:16, 0:16, 0:16>>,
    QName  = compose_response:encode_name(QNameFqdn),
    QType  = parse_query:qtype_value(QTypeAtom),
    <<Header/binary, QName/binary, QType:16, 1:16>>.

%% Decode a response: returns {Id, Rcode, AnCount, Tc}.
decode_header(<<Id:16, Flags:16, _Qd:16, AnCount:16, _Ns:16, _Ar:16, _/binary>>) ->
    Rcode = Flags band 16#0F,
    Tc    = (Flags bsr 9) band 1,
    {Id, Rcode, AnCount, Tc}.

%% Seed a station_endpoint record + return its MRI / qname / a stub
%% find_fn keyed by its storage key.
seed_station(Hosts) ->
    St   = macula_identity:generate(),
    StPk = macula_identity:public(St),
    Z32  = macula_z32:encode(StPk),
    {ok, QName} = qname_to_mri:format(<<"mri:station:", Z32/binary>>),
    Rec  = macula_record:sign(
             macula_record:station_endpoint(StPk, 4433, #{host_advertised => Hosts}),
             St),
    Key  = macula_record:storage_key(Rec),
    Find = fun(_P, K) -> case K =:= Key of true -> {ok, Rec};
                                            false -> {error, not_found} end end,
    {QName, Find}.

%%====================================================================
%% Tests
%%====================================================================

non_mesh_is_refused(_Config) ->
    Q = make_query(16#0001, <<"www.example.com.">>, a),
    {ok, Resp} = serve_query:handle(undefined, Q, #{}),
    {16#0001, ?REFUSED, 0, 0} = decode_header(Resp),
    ok.

axfr_is_refused(_Config) ->
    Q = make_query(16#0002, <<"macula.io.">>, axfr),
    {ok, Resp} = serve_query:handle(undefined, Q, #{}),
    {16#0002, ?REFUSED, 0, 0} = decode_header(Resp),
    ok.

no_pool_mesh_query_is_servfail(_Config) ->
    %% A mesh qname but no mesh pool → SERVFAIL (we can't resolve).
    Q = make_query(16#0003, <<"alice._u.acme.macula.io.">>, aaaa),
    {ok, Resp} = serve_query:handle(undefined, Q, #{}),
    {16#0003, ?SERVFAIL, 0, 0} = decode_header(Resp),
    ok.

station_aaaa_resolves(_Config) ->
    {QName, Find} = seed_station([<<"fc00::abc">>, <<"::1">>]),
    Q = make_query(16#0004, QName, aaaa),
    %% Pass a non-undefined Pool (self/1 — never actually used since
    %% find_fn is stubbed) + the stub find_fn.
    {ok, Resp} = serve_query:handle(self(), Q, #{find_fn => Find,
                                                 max_attempts => 1,
                                                 retry_delay_ms => 0}),
    {16#0004, ?NOERROR, AnCount, 0} = decode_header(Resp),
    %% Two v6 hosts advertised → two AAAA RRs.
    2 = AnCount,
    ok.

station_v4_only_aaaa_is_nodata(_Config) ->
    {QName, Find} = seed_station([<<"192.0.2.7">>]),
    Q = make_query(16#0005, QName, aaaa),
    {ok, Resp} = serve_query:handle(self(), Q, #{find_fn => Find,
                                                 max_attempts => 1,
                                                 retry_delay_ms => 0}),
    %% NOERROR, no answer — the name exists, just no AAAA record.
    {16#0005, ?NOERROR, 0, 0} = decode_header(Resp),
    ok.

user_mri_is_servfail(_Config) ->
    %% A well-formed user qname resolves to mri:user:... which
    %% resolve_mesh_names returns {not_resolvable_yet, user} →
    %% SERVFAIL + EDE("not_resolvable_yet").
    Q = make_query(16#0006, <<"alice._u.acme.macula.io.">>, aaaa),
    {ok, Resp} = serve_query:handle(self(), Q, #{find_fn => fun(_,_) -> {error, not_found} end,
                                                 max_attempts => 1,
                                                 retry_delay_ms => 0}),
    {16#0006, ?SERVFAIL, 0, 0} = decode_header(Resp),
    ok.

garbled_packet_is_dropped(_Config) ->
    drop = serve_query:handle(undefined, <<1, 2, 3>>, #{}),
    drop = serve_query:handle(undefined, <<>>, #{}),
    ok.

zero_question_is_formerr(_Config) ->
    %% Valid 12-byte header, QDCOUNT=0 → FORMERR (echoing the id).
    Header = <<16#0007:16, (1 bsl 8):16, 0:16, 0:16, 0:16, 0:16>>,
    {ok, Resp} = serve_query:handle(undefined, Header, #{}),
    {16#0007, ?FORMERR, 0, 0} = decode_header(Resp),
    ok.
