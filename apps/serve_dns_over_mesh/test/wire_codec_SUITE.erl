%%% @doc CT suite for the RFC 1035 wire codec — parse_query,
%%% compose_response, compose_ede — plus classify_qname.
%%% PLAN_DNS_OVER_MESH_PART1 §5, §6, §9.1.
%%%
%%% Coverage:
%%%   - parse a hand-built query → id / qname / qtype / rd
%%%   - parse a query carrying an EDNS0 OPT pseudo-RR → edns0 map
%%%   - parse rejects malformed packets (too short, zero questions)
%%%   - compose a NOERROR/AAAA response, re-decode to verify shape
%%%   - compose a SERVFAIL+EDE response → OPT RR with EDE option
%%%   - compose truncates an oversized response → TC=1, empty body
%%%   - round-trip: query → parse → compose → response echoes the
%%%     question and carries the original id
%%%   - compose_ede:info/1 maps the §6 causes to the right codes
%%%   - classify_qname: suffix match / non-mesh / case-insensitive /
%%%     label-boundary (no "evilmacula.io" false positive)
%%% @end
-module(wire_codec_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([
    parse_basic_query/1,
    parse_query_with_edns0/1,
    parse_rejects_short_packet/1,
    parse_rejects_zero_questions/1,
    compose_noerror_aaaa/1,
    compose_servfail_with_ede/1,
    compose_truncates_oversized/1,
    roundtrip_query_to_response/1,
    ede_info_codes/1,
    classify_mesh_suffix/1,
    classify_non_mesh/1,
    classify_case_insensitive/1,
    classify_label_boundary/1
]).

all() ->
    [
        parse_basic_query,
        parse_query_with_edns0,
        parse_rejects_short_packet,
        parse_rejects_zero_questions,
        compose_noerror_aaaa,
        compose_servfail_with_ede,
        compose_truncates_oversized,
        roundtrip_query_to_response,
        ede_info_codes,
        classify_mesh_suffix,
        classify_non_mesh,
        classify_case_insensitive,
        classify_label_boundary
    ].

init_per_suite(Config) ->
    application:set_env(serve_dns_over_mesh, mesh_suffix, <<"macula.io.">>),
    Config.
end_per_suite(_Config) -> ok.

%%====================================================================
%% Helpers — build raw DNS query packets by hand
%%====================================================================

%% A minimal standard query: RD=1, one question, no EDNS0.
make_query(Id, QNameFqdn, QTypeAtom) ->
    %% Flags: QR=0, Opcode=0, AA=0, TC=0, RD=1, RA=0, Z=0, RCODE=0
    Flags = 1 bsl 8,
    Header = <<Id:16, Flags:16, 1:16, 0:16, 0:16, 0:16>>,
    QName  = compose_response:encode_name(QNameFqdn),
    QType  = parse_query:qtype_value(QTypeAtom),
    Question = <<QName/binary, QType:16, 1:16>>,   %% class IN
    <<Header/binary, Question/binary>>.

%% A query carrying an EDNS0 OPT pseudo-RR in the additional
%% section advertising a 4096-byte UDP buffer.
make_query_edns0(Id, QNameFqdn, QTypeAtom) ->
    Flags = 1 bsl 8,
    Header = <<Id:16, Flags:16, 1:16, 0:16, 0:16, 1:16>>,  %% ARCOUNT=1
    QName  = compose_response:encode_name(QNameFqdn),
    QType  = parse_query:qtype_value(QTypeAtom),
    Question = <<QName/binary, QType:16, 1:16>>,
    %% OPT RR: NAME=root(0x00), TYPE=41, CLASS=4096 (UDP size),
    %% TTL=0 (ext-rcode/version/flags all 0), RDLENGTH=0, no RDATA.
    Opt = <<0:8, 41:16, 4096:16, 0:32, 0:16>>,
    <<Header/binary, Question/binary, Opt/binary>>.

%%====================================================================
%% parse_query
%%====================================================================

parse_basic_query(_Config) ->
    Q = make_query(16#1234, <<"alice._u.acme.macula.io.">>, aaaa),
    {ok, Parsed} = parse_query:parse(Q),
    #{id        := 16#1234,
      opcode    := 0,
      rd        := true,
      qname     := <<"alice._u.acme.macula.io.">>,
      qtype     := aaaa,
      qclass    := in,
      edns0     := undefined} = Parsed,
    ok.

parse_query_with_edns0(_Config) ->
    Q = make_query_edns0(16#ABCD, <<"counter._a.acme.macula.io.">>, a),
    {ok, Parsed} = parse_query:parse(Q),
    #{id    := 16#ABCD,
      qtype := a,
      edns0 := #{udp_size := 4096, version := 0, do := false}} = Parsed,
    ok.

parse_rejects_short_packet(_Config) ->
    {error, malformed_packet} = parse_query:parse(<<1, 2, 3>>),
    {error, malformed_packet} = parse_query:parse(<<>>),
    ok.

parse_rejects_zero_questions(_Config) ->
    %% Valid 12-byte header but QDCOUNT=0.
    Header = <<16#1111:16, (1 bsl 8):16, 0:16, 0:16, 0:16, 0:16>>,
    {error, no_question} = parse_query:parse(Header),
    ok.

%%====================================================================
%% compose_response
%%====================================================================

compose_noerror_aaaa(_Config) ->
    Q = make_query(16#0001, <<"alice._u.acme.macula.io.">>, aaaa),
    {ok, QMap} = parse_query:parse(Q),
    Spec = #{query   => QMap,
             rcode   => noerror,
             aa      => true,
             answers => [#{name  => <<"alice._u.acme.macula.io.">>,
                           type  => aaaa,
                           ttl   => 300,
                           rdata => {16#fc00, 0, 0, 0, 0, 0, 0, 16#abc}}],
             ede     => none},
    {ok, Wire} = compose_response:compose(Spec),
    %% Re-decode the header to verify QR=1, AA=1, RCODE=0, ANCOUNT=1.
    <<Id:16, Flags:16, QdCount:16, AnCount:16, _NsCount:16, _ArCount:16,
      _Rest/binary>> = Wire,
    16#0001 = Id,
    1       = QdCount,
    1       = AnCount,
    1       = (Flags bsr 15) band 1,    %% QR
    1       = (Flags bsr 10) band 1,    %% AA
    0       = Flags band 16#0F,          %% RCODE = NOERROR
    1       = (Flags bsr 8) band 1,      %% RD echoed
    ok.

compose_servfail_with_ede(_Config) ->
    Q = make_query_edns0(16#0002, <<"bob._u.acme.macula.io.">>, aaaa),
    {ok, QMap} = parse_query:parse(Q),
    Spec = #{query   => QMap,
             rcode   => servfail,
             aa      => false,
             answers => [],
             ede     => sig_indeterminate},
    {ok, Wire} = compose_response:compose(Spec),
    <<_Id:16, Flags:16, _Qd:16, AnCount:16, _Ns:16, ArCount:16, _Rest/binary>> = Wire,
    2 = Flags band 16#0F,    %% RCODE = SERVFAIL
    0 = AnCount,
    1 = ArCount,             %% the OPT pseudo-RR
    %% The wire must contain the EDE option's extra-text.
    {_, _} = binary:match(Wire, <<"sig_indeterminate">>),
    ok.

compose_truncates_oversized(_Config) ->
    %% No EDNS0 → 512-byte limit. Stuff in enough TXT to blow past it.
    Q = make_query(16#0003, <<"big.macula.io.">>, txt),
    {ok, QMap} = parse_query:parse(Q),
    BigString = binary:copy(<<"x">>, 250),
    ManyTxt = [#{name => <<"big.macula.io.">>, type => txt, ttl => 60,
                 rdata => [BigString]} || _ <- lists:seq(1, 10)],
    Spec = #{query => QMap, rcode => noerror, aa => true,
             answers => ManyTxt, ede => none},
    {ok, Wire} = compose_response:compose(Spec),
    true = byte_size(Wire) =< 512,
    <<_Id:16, Flags:16, _Qd:16, AnCount:16, _:16, _:16, _Rest/binary>> = Wire,
    1 = (Flags bsr 9) band 1,    %% TC = 1
    0 = AnCount,                  %% body dropped
    ok.

roundtrip_query_to_response(_Config) ->
    Q = make_query(16#5A5A, <<"x._u.acme.macula.io.">>, a),
    {ok, QMap} = parse_query:parse(Q),
    Spec = #{query => QMap, rcode => nxdomain, aa => true,
             answers => [], ede => name_revoked},
    {ok, Wire} = compose_response:compose(Spec),
    %% The response's question section must echo the original.
    <<RId:16, _Flags:16, 1:16, _An:16, _Ns:16, _Ar:16, AfterHdr/binary>> = Wire,
    16#5A5A = RId,
    {ok, RQName, AfterName} = parse_query:decode_name(AfterHdr, Wire),
    <<QTypeN:16, 1:16, _/binary>> = AfterName,
    <<"x._u.acme.macula.io">> = RQName,
    1 = QTypeN,    %% type A
    ok.

%%====================================================================
%% compose_ede
%%====================================================================

ede_info_codes(_Config) ->
    {18, <<"no_trust_root">>}          = compose_ede:info(no_trust_root),
    {22, <<"trust_list_unavailable">>} = compose_ede:info(trust_list_unavailable),
    {6,  <<"realm_dir_bogus">>}        = compose_ede:info(realm_dir_bogus),
    {6,  <<"name_revoked">>}           = compose_ede:info(name_revoked),
    {6,  <<"sig_indeterminate">>}      = compose_ede:info(sig_indeterminate),
    {18, <<"realm_not_trusted">>}      = compose_ede:info(realm_not_trusted),
    {0,  <<"not_resolvable_yet">>}     = compose_ede:info({not_resolvable_yet, user}),
    {0,  <<"other">>}                  = compose_ede:info(some_unknown_cause),
    %% option/2 produces the wire OPT-OPTION with the detail appended.
    Opt = compose_ede:option(realm_not_trusted, <<"io.evil">>),
    {_, _} = binary:match(Opt, <<"realm_not_trusted:io.evil">>),
    %% `none' → no option.
    <<>> = compose_ede:option(none, undefined),
    ok.

%%====================================================================
%% classify_qname
%%====================================================================

classify_mesh_suffix(_Config) ->
    mesh = classify_qname:classify(<<"alice._u.acme.macula.io.">>),
    mesh = classify_qname:classify(<<"macula.io.">>),          %% the apex
    mesh = classify_qname:classify(<<"alice._u.acme.macula.io">>),  %% no trailing dot
    ok.

classify_non_mesh(_Config) ->
    not_mesh = classify_qname:classify(<<"www.example.com.">>),
    not_mesh = classify_qname:classify(<<"random.">>),
    not_mesh = classify_qname:classify(<<"io.">>),
    ok.

classify_case_insensitive(_Config) ->
    mesh = classify_qname:classify(<<"Alice._U.ACME.Macula.IO.">>),
    ok.

classify_label_boundary(_Config) ->
    %% Must NOT match — "evilmacula.io" is not under "macula.io."
    %% (no label boundary before "macula.io").
    not_mesh = classify_qname:classify(<<"evilmacula.io.">>),
    not_mesh = classify_qname:classify(<<"notmacula.io.">>),
    ok.
